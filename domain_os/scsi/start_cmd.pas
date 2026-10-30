{ scsi_start_cmd - select a target for its first pending request.

  Image addresses:
    sau9  0x3C4A6F0E  scsi_start_cmd

  Assume we're called with the SCSI spin lock held.

  - The IDENTIFY (disconnect allowed, the command's logical unit) goes
    first; a target not yet negotiated with gets a synchronous transfer
    request too (the bus's shortest period, rounded to 4 ns units, and
    its largest offset), selected with attention and stopping after the
    IDENTIFY; any other is selected with its command bytes.
  - A target with nothing pending crashes the system.
}

procedure scsi_start_cmd(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                         tid: integer); internal;
var
  req: scsi_req_ptr_t;
  regs: c90_regs_ptr_t;
  i: integer;
begin
  req := tgt^.pend_head;
  if req = nil then
    crash_system(status_$scsi_internal_error);
  regs := cb^.regs;
  regs^.cmd := c90_cmd_flush_fifo;
  regs^.r10.dest.id := tid;
  regs^.r14.sel_timeout := cb^.sel_timeout;
  regs^.r18.sync.period := tgt^.sync_period;
  regs^.r1c.sync.offset := tgt^.sync_offset;
  if tgt^.sync_state = scsi_sync_none then begin
    cb^.msg_count := 5;
    cb^.msg[0] := scsi_msg_extended;
    cb^.msg[1] := scsi_xmsg_sdtr_len;
    cb^.msg[2] := scsi_xmsg_sdtr;
    cb^.msg[3] := (cb^.min_period * 10 div 4 + 5) div 10;
    cb^.msg[4] := cb^.max_offset;
    cb^.send_atn := true;
    tgt^.sync_state := scsi_sync_requested;
  end;
  regs^.fifo := scsi_msg_identify_disc ! req^.cdb.f.lun;
  if cb^.send_atn then begin
    cb^.send_atn := false;
    regs^.cmd := c90_cmd_select_atn_stop;
  end
  else begin
    for i := 0 to req^.cdb_len - 1 do
      regs^.fifo := ord(req^.cdb.b[i]);
    regs^.cmd := c90_cmd_select_atn;
  end;
  cb^.connected := true;
  cb^.cur_target := tid;
  cb^.disc_pending := false;
  tgt^.active := true;
  tgt^.msg_out_state := scsi_mo_none;
  tgt^.state := scsi_ts_select;
  tgt^.last_msg[0] := scsi_msg_nop;
  tgt^.last_msg_len := 1;
end;
