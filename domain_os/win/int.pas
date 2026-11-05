{ WIN_$INT - the Winchester controller's interrupt routine.

  Image addresses:
    sau2  0x00E19BFA  WIN_$INT
    sau4  0x0F81A72E  WIN_$INT
    sau5  0x00E1A0CE  WIN_$INT
    sau6  0x7801A4B0  WIN_$INT

  - The ANSI form, with a chain in progress: at priority 5, the drive's
    status is posted to win_status; a finished seek starts its transfer,
    a finished transfer steps to the next request.
  - The ring/disk form acknowledges the board's interrupt first; a
    finished seek is checked on the drive's interface; a finished
    transfer checks the controller's status and the DMA counts, a bus
    error or an unknown status crashing the system.
  - WIN_$DO_IO is woken when the chain is done or failed.
  - The descriptor-list form saves the status word; one descriptor done
    moves the request on, anything else ends the command and wakes the
    waiter.  The result is true.

  Status stored: none.
}

%if win_descriptor_ctlr %then
function win_$int(in dcte: dcte_t): boolean;
var
  unit: pinteger;
  regs: win_$regs_ptr_t;
%if win_vectored_ctlr %then
  status: pinteger;
%endif
begin
  unit := dcte.cnum;
  regs := win_units[unit].regs;
%if win_vectored_ctlr %then
  status := regs^.status;
  if (status & win_status_int) = 0 then begin
    win_$int := false;
    return;
  end;
  win_stat := status;
%else
  win_stat := regs^.status;
%endif
  if (win_stat & 16#DCFF) = 16#C800 then begin
    { one descriptor done: on to the next request }
    if win_cur_req <> nil then
      win_cur_req := win_cur_req^.next;
  end
  else begin
    { the command finished: wake the waiter }
    ec_$advance_without_dispatch(win_unit_ec[unit]);
    win_$timeout_st := regs^.timeout_st;
    win_err := regs^.error;
  end;
  regs^.go := 1;
  win_$int := true;
end;
%elseif win_ring_disk_ctlr %then
function win_$int(in dcte: dcte_t): boolean;
label
  50, 99;
var
  ctlr: pinteger;
  regs: win_$regs_ptr_t;
  vol: win_$vol_ptr_t;
  done: boolean;
  s: integer32;
  count0: integer;
  count1: integer;
begin
  ctlr := dcte.cnum;
  regs := win_units[ctlr].regs;
  vol := win_dev_info;
  regs^.int_ack := 0;
  regs^.control := win_ctl_off;

  if win_cur_req <> nil then begin
    done := false;
    win_status := status_$ok;

    if win_flag then begin
      { a seek finished: on the cylinder, then the transfer }
      win_flag := false;
      if win_smd_interface in win_units[ctlr].unit_bits then
        if (regs^.cmd & 16#0F) = 3 then begin
          win_cyls[vol^.dev_unit] := win_cur_req^.daddr.cyl;
          win_status := status_$ok;
        end
        else
          win_status := status_$disk_seek_error
      else if (regs^.cmd & 16#B7) = 3 then
        win_status := status_$ok
      else
        win_status := status_$disk_seek_error;
      if win_status = status_$ok then
        win_status := read_or_write_disk_record(vol^, win_cur_req^);
    end
    else begin
      { a transfer finished: the drive's and the controller's status }
      if win_smd_interface in win_units[ctlr].unit_bits then
        regs^.cmd := 1
      else if win_st_drive_fault in regs^.status then
        goto 50;
      if regs^.ctlr_status <> 0 then begin
50:     if ((win_smd_interface in win_units[ctlr].unit_bits) and
            (3 in regs^.status)) or
           (not (win_smd_interface in win_units[ctlr].unit_bits) and
            (win_st_drive_fault in regs^.status)) then begin
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
          win_status := status_$disk_equipment_check;
        end
        else if win_cs_timeout in regs^.ctlr_bits then begin
          win_$cnt.w_10 := win_$cnt.w_10 + 1;
          win_status := status_$drive_timed_out;
        end
        else if win_cs_bus_error in regs^.ctlr_bits then
          crash_system(status_$bus_error_occurred_during_disk_dma_transfer)
        else if win_cs_overrun in regs^.ctlr_bits then begin
          win_$cnt.dma_overruns := win_$cnt.dma_overruns + 1;
          win_status := status_$dma_overrun;
        end
        else if win_cs_crc_error in regs^.ctlr_bits then begin
          win_$cnt.data_checks := win_$cnt.data_checks + 1;
          win_status := status_$disk_data_check;
        end
        else begin
          win_status := status_$unknown_status_returned_by_hardware;
          crash_system(status_$unknown_status_returned_by_hardware);
        end;
      end
      else begin
        { both DMA channels at the end of their counts }
        regs^.dma_clear_ptr := 0;
        count0 := regs^.dma_count0 + lshft(regs^.dma_count0, 8) + 1;
        count1 := regs^.dma_count1 + lshft(regs^.dma_count1, 8) + 1;
        if (count0 <> 0) or else (count1 <> 0) then begin
          crash_system(status_$dma_not_at_end_of_range);
          win_status := status_$dma_not_at_end_of_range;
        end;
      end;

      if win_status = status_$ok then begin
        { on to the next request }
        win_cur_req := win_cur_req^.next;
        if win_cur_req = nil then
          done := true
        else begin
          s := seek(ctlr, vol^.dev_unit, win_cur_req^.daddr.cyl, false);
          if s = status_$ok then
            win_status := read_or_write_disk_record(vol^, win_cur_req^)
          else if s > 0 then
            win_status := s;
        end;
      end;
    end;

    if win_status <> status_$ok then begin
      done := true;
      regs^.control := win_ctl_off;
    end;
    if not done then
      goto 99;
  end;

  { wake WIN_$DO_IO }
  ec_$advance_without_dispatch(win_unit_ec[ctlr]);

99:
  win_$int := true;
end;
%else

{ TODO(pascal) four frame bytes in WIN_$INT

  In the SAU2 frame s (4), regs (4), unit (2), done (2) and the boolean
  result variable (2) explain 0xE bytes, rounded to 0x10, of 0x14;
  nothing in the routine addresses the frame.  The stand-in unused_14
  holds the other 4.  A word local for set_sr's old value would take 2
  of them; what they were is not known. }

function win_$int(in dcte: dcte_t): boolean;
label
  99;
var
  s: integer32;
  regs: win_$regs_ptr_t;
  unit: pinteger;
  done: boolean;
  unused_14: integer32;                   { never addressed: the TODO }
begin
  unit := dcte.cnum;
  regs := win_units[unit].regs;
  regs^.mode := 0;

  if win_cur_req <> nil then begin
    done := false;
    discard(set_sr(16#2500));
    win_status := win_$check_disk_status(unit);

    if win_flag then begin
      { a seek finished }
      win_flag := false;
      if win_status = status_$ok then begin
        win_cur_cyl := win_cur_req^.daddr.cyl;
        s := read_or_write_disk_record(unit);
        win_status := s;
      end;
    end
    else begin
      { a transfer finished }
      s := dma_$check(3);
      if win_status = status_$ok then
        win_status := s;
      if win_status = status_$ok then begin
        { on to the next request }
        win_cur_req := win_cur_req^.next;
        if win_cur_req = nil then
          done := true
        else begin
          s := seek(unit, win_dev_info^.dev_unit, win_cur_req^, false);
          if s = status_$ok then begin
            s := read_or_write_disk_record(unit);
            win_status := s;
          end
          else if s > 0 then
            win_status := s;
        end;
      end;
    end;

    if win_status <> status_$ok then
      done := true;
    if not done then
      goto 99;
  end;

  { wake WIN_$DO_IO }
  ec_$advance_without_dispatch(win_unit_ec[unit]);

99:
  win_$int := true;
end;
%endif
