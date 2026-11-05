{ WIN8_$INT - the controller's interrupt routine.

  Image addresses:
    sau7  0x3C41D860  WIN8_$INT
    sau8  0x03C1AE8C  WIN8_$INT

  - With the controller's interrupt bit set, its interrupt is turned off
    and the controller's eventcount advanced.  The result is true.

  Status stored: none.
}

function win8_$int(in dcte: win_$dcte_t): boolean;
var
  regs: win_$regs_ptr_t;
begin
  regs := win_$regs_ptr_t(dcte.req.csr.va);
  if (regs^.status & 16#20) <> 0 then begin
    regs^.ctl := win_ctl_int_off;
    ec_$advance_without_dispatch(win_unit_ec[dcte.cnum]);
  end;
  win8_$int := true;
end;
