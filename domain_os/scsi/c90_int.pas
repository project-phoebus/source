{ SCSI_$C90_INT - handle the 53C90's interrupt.

  Image addresses:
    sau9  0x3C4A5774  SCSI_$C90_INT

  - Runs under the SCSI spin lock, until the controller has no interrupt
    pending; each pass reads the FIFO flags, the sequence step, the
    status and the interrupt registers, in that order.
  - Being selected, an illegal command, a bus reset or a gross error
    crashes the system.
  - A reselection names its target by the one bit besides the
    controller's in the FIFO's first byte.
  - The connected target's state says what the interrupt ends; the bus
    phase then says what comes next (scsi_phase_dispatch).  A target
    that disconnects after its command's last message, or after the
    driver's own message, has its request done; one that disconnects
    otherwise must have said DISCONNECT.
  - With no target left on the bus, reselection is enabled and the next
    request started.

  Returns:
    true: always
}

function scsi_$c90_int(cb: scsi_cb_ptr_t): boolean;
var
  token: integer;
  ff: integer;
  seq: [byte] 0..255;
  stat: c90_status_t;
  intr: c90_intr_t;
  junk: array[0..15] of char;
  resel: array[0..7] of char;
  msgw: array[1..8] of pinteger;
  regs: c90_regs_ptr_t;
  n: pinteger;
  i: integer;
  mask: integer;
  tid: integer;
  code: integer;
  parity: boolean;
  tgt: scsi_target_ptr_t;
  req: scsi_req_ptr_t;
begin
  token := ml_$spin_lock(scsi_lock);
  repeat
    ff := cb^.regs^.r1c.fifo_flags_byte;
    seq := cb^.regs^.r18.seq_step;
    stat := cb^.regs^.r10.status;
    intr := cb^.regs^.r14.intr;
    if intr.selected or else intr.selected_atn then begin
      n := ff & 16#1F;
      for i := 0 to n - 1 do
        junk[i] := chr(cb^.regs^.fifo);
      crash_system(status_$scsi_selected_by_initiator);
    end
    else if intr.illegal_cmd then
      crash_system(status_$scsi_internal_error)
    else if intr.scsi_reset then
      crash_system(status_$scsi_bus_reset_detected)
    else if stat.gross_error then
      crash_system(status_$scsi_internal_error);

    if cb^.connected then
      tgt := addr(cb^.target[cb^.cur_target])
    else
      tgt := nil;

    { A reselection: the target is the bit besides the controller's. }
    if intr.reselected then begin
      n := ff & 16#1F;
      for i := 0 to n - 1 do
        resel[i] := chr(cb^.regs^.fifo);
      if tgt <> nil then
        if tgt^.state = scsi_ts_select then
          tgt^.active := false
        else
          crash_system(status_$scsi_internal_error);
      resel[0] := chr(ord(resel[0]) & 16#7F);
      if ord(resel[0]) = 0 then
        crash_system(status_$scsi_illegal_reselection);
      mask := 1;
      tid := 0;
      for i := 0 to 6 do begin
        if (ord(resel[0]) & mask) <> 0 then
          exit;
        mask := mask * 2;
        tid := tid + 1;
      end;
      cb^.cur_target := tid;
      tgt := addr(cb^.target[cb^.cur_target]);
      tgt^.state := scsi_ts_reselected;
      cb^.connected := true;
    end;

    if (tgt = nil) or else (tgt^.pend_head = nil) then
      crash_system(status_$scsi_internal_error);
    req := tgt^.pend_head;

    if cb^.disc_pending and then intr.disconnect then begin
      tgt^.active := false;
      cb^.connected := false;
      cb^.dma_count := 0;
      scsi_complete_req(tgt);
    end
    else if intr.disconnect and then (tgt^.msg_out_state = scsi_mo_sent) then begin
      cb^.dma_count := 0;
      cb^.connected := false;
      tgt^.active := false;
      scsi_complete_req(tgt);
    end
    else if intr.disconnect
            and then not ((tgt^.state = scsi_ts_status)
                     or (tgt^.state = scsi_ts_select)
                     or (tgt^.state = scsi_ts_msg_done)) then begin
      cb^.dma_count := 0;
      if tgt^.last_msg[0] <> scsi_msg_disconnect then
        crash_system(status_$scsi_target_disconnected);
      tgt^.state := scsi_ts_disconnected;
      cb^.connected := false;
    end
    else
      case tgt^.state of
        scsi_ts_data_out, scsi_ts_data_in: begin
          parity := parity_$chk_io(0) <> 0;
          if parity then
            req^.result.status.all := status_$scsi_parity_error;
          scsi_finish_data(cb, req);
          scsi_phase_dispatch(cb, tgt, req, stat.phase);
        end;

        scsi_ts_select: begin
          if intr.disconnect then begin
            tgt^.active := false;
            cb^.connected := false;
            req^.result.status.all := status_$scsi_target_not_available;
            scsi_complete_req(tgt);
          end
          else begin
            cb^.never_selected := false;
            scsi_phase_dispatch(cb, tgt, req, stat.phase);
          end;
        end;

        { The status byte, and the message after it. }
        scsi_ts_status: begin
          regs := cb^.regs;
          code := regs^.fifo & 16#1E;
          case code of
            0: req^.result.scsi_status := scsi_$st_good;
            2: req^.result.scsi_status := scsi_$st_check_condition;
            4: req^.result.scsi_status := scsi_$st_condition_met;
            8: req^.result.scsi_status := scsi_$st_busy;
            16: req^.result.scsi_status := scsi_$st_intermediate;
            24: req^.result.scsi_status := scsi_$st_reservation_conflict;
            otherwise
              req^.result.scsi_status := scsi_$st_other;
          end;
          n := regs^.r1c.fifo_flags.count;
          if n <> 0 then begin
            for i := 1 to n do
              msgw[i] := regs^.fifo;
            scsi_msg_in(cb, tgt, req, msgw, n);
          end
          else if intr.disconnect then begin
            tgt^.active := false;
            cb^.connected := false;
            cb^.dma_count := 0;
            scsi_complete_req(tgt);
          end
          else
            scsi_phase_dispatch(cb, tgt, req, stat.phase);
        end;

        scsi_ts_msg_out: begin
          cb^.regs^.cmd := c90_cmd_flush_fifo;
          cb^.msg[0] := scsi_msg_nop;
          cb^.msg_count := 1;
          scsi_phase_dispatch(cb, tgt, req, stat.phase);
        end;

        { A message in byte; an extended message waits for its length. }
        scsi_ts_msg_in: begin
          cb^.msg[cb^.msg_index] := cb^.regs^.fifo;
          cb^.msg_count := cb^.msg_count + 1;
          if cb^.msg[0] = scsi_msg_extended then
            if (cb^.msg_index <> 0)
               and then (cb^.msg[1] + 2 = cb^.msg_count) then begin
              scsi_msg_in(cb, tgt, req, cb^.msg, cb^.msg_count);
              cb^.msg_count := 0;
              cb^.msg_index := 0;
            end
            else begin
              cb^.regs^.cmd := c90_cmd_msg_accepted;
              tgt^.state := scsi_ts_msg_in_more;
            end
          else
            scsi_msg_in(cb, tgt, req, cb^.msg, 1);
        end;

        scsi_ts_msg_in_more: begin
          scsi_phase_dispatch(cb, tgt, req, stat.phase);
        end;

        { A reselection: the target's transfer parameters; an IDENTIFY
          and more in the FIFO count as RESTORE POINTERS. }
        scsi_ts_reselected: begin
          cb^.regs^.r18.sync.period := tgt^.sync_period;
          cb^.regs^.r1c.sync.offset := tgt^.sync_offset;
          if n <= 1 then
            scsi_phase_dispatch(cb, tgt, req, stat.phase)
          else begin
            msgw[1] := scsi_msg_restore_pointers;
            scsi_msg_in(cb, tgt, req, msgw, 1);
          end;
        end;

        scsi_ts_msg_done: begin
          if intr.disconnect then begin
            tgt^.active := false;
            cb^.connected := false;
            cb^.dma_count := 0;
            scsi_complete_req(tgt);
          end
          else begin
            cb^.disc_pending := true;
            scsi_phase_dispatch(cb, tgt, req, stat.phase);
          end;
        end;

        otherwise begin
          crash_system(status_$scsi_internal_error);
        end;
      end;

    if not cb^.connected then begin
      scsi_enable_select(cb);
      scsi_start_next(cb);
    end;
  until not cb^.regs^.r10.status.int;
  ml_$spin_unlock(scsi_lock, token);
  scsi_$c90_int := true;
end;
