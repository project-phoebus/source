%if ct_atbus_qic02 %then
{ CT_$INT - the cartridge tape's interrupt routine.

  Image addresses:
    sau7  0x3C48711E  CT_$INT
    sau8  0x03C7B39A  CT_$INT

  - With the AT bus adapter (`ct_atbus_qic02'): the adapter's control
    port is cleared, an exception noted from its status, the command no
    longer outstanding, and the driver's eventcount advanced.  The
    DCTE is not read.  The result is true: the interrupt was the
    tape's.

  Status stored: none.
}

function ct_$int(in dcte: dcte_t): boolean;
begin
  ct_regs^.ctl := 0;
  ct_exception := not ct_regs^.stat.no_exception;
  ct_busy := false;
  ec_$advance_without_dispatch(ct_ec);
  ct_$int := true;
end;
%else
{ CT_$INT - the cartridge tape controller's interrupt routine.

  Image addresses:
    sau5  0x00E77C36  CT_$INT
    sau6  0x7807EF68  CT_$INT

  - The controller's and the drive's status words are saved for
    ct_decode_status, the go byte (1) written to acknowledge, the
    command marked done and the eventcount advanced without a dispatch.
  - The result is true (the interrupt was the controller's); with
    `ct_vectored_ctlr' it is false, and nothing else is done, when the
    controller's status word does not show its interrupt.

  Status stored: none.
}

function ct_$int(in dcte: dcte_t): boolean;
begin
  with ct_regs^ do begin
    ct_cstat.all := cstat;
%if ct_vectored_ctlr %then
    if (ct_cstat.all & ct_cstat_int) = 0 then begin
      ct_$int := false;
      return;
    end;
%endif
    ct_dstat.all := dstat;
    go := 1;
  end;
  ct_busy := false;
  ec_$advance_without_dispatch(ct_ec);
  ct_$int := true;
end;
%endif
