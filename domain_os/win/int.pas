{ WIN_$INT - the Winchester controller's interrupt routine.

  Image addresses:
    sau2  0x00E19BFA  WIN_$INT
    sau5  0x00E1A0CE  WIN_$INT

  - The ANSI form, with a chain in progress: at priority 5, the drive's
    status is posted to win_status; a finished seek starts its transfer,
    a finished transfer steps to the next request.
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
begin
  unit := dcte.cnum;
  regs := win_units[unit].regs;
  win_stat := regs^.status;
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
