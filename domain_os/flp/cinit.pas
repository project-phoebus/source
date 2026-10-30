{ FLP_$CINIT - initialize a floppy controller.

  Image addresses:
    sau2  0x00E3E002  FLP_$CINIT

  - The driver is registered with DISK only after SPECIFY succeeded.

  Returns:
    status_$ok: the controller is initialized
    status_$io_controller_not_in_system: the probe fails
    status_$disk_controller_error: the controller is not drained in 200
      tries
    SHAKE's result: SPECIFY fails

  Status stored: none.
}

function flp_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  probe_data: array[1..10] of char;
  sense: pinteger;
  tries: pinteger;
  ctlr: pinteger;                         { held in a register; its slot
                                            for the by-address call }
begin
  if not testpage(0, dcte.disk_dinit, probe_data) then begin
    flp_$cinit := status_$io_controller_not_in_system;
    return;
  end;

  ctlr := dcte.cnum;
  flp_hw_addr := dcte.disk_dinit;
  flp_ctlr_table[ctlr].dcte := addr(dcte);
  flp_ctlr_table[ctlr].hw_addr := flp_hw_addr;

  ec_$init(flp_$ec);

  { drain the controller }
  with flp_hw_addr^ do begin
    status := status_$ok;
    tries := 0;
    while (main_status & 16#1F) <> 0 do begin
      if 6 in main_status_bits then
        discard(shake(flp_$sregs, 3, 0))
      else begin
        sense := 8;
        discard(shake(sense, 1, 1));
      end;
      tries := tries + 1;
      if tries > 200 then begin
        status := status_$disk_controller_error;
        exit;
      end;
    end;
  end;

  { SPECIFY, then the registration }
  if status = status_$ok then begin
    status := shake(flp_specify_cmd, 3, 1);
    if status = status_$ok then
      discard(disk_$register(1, ctlr, flp_unit_count,
                             dcte.disk_error_que_hi,
                             addr(flp_jump_table)));
  end;

  flp_$cinit := status;
end;
