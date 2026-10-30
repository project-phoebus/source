{ CT_$INT - the cartridge tape controller's interrupt routine.

  Image addresses:
    sau5  0x00E77C36  CT_$INT

  - The controller's and the drive's status words are saved for
    ct_decode_status, the go byte (1) written to acknowledge, the
    command marked done and the eventcount advanced without a dispatch.
  - The result is true (the interrupt was the controller's).

  Status stored: none.
}

function ct_$int(in dcte: dcte_t): boolean;
begin
  with ct_regs^ do begin
    ct_cstat.all := cstat;
    ct_dstat.all := dstat;
    go := 1;
  end;
  ct_busy := false;
  ec_$advance_without_dispatch(ct_ec);
  ct_$int := true;
end;
