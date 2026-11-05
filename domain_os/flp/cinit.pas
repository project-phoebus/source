{ FLP_$CINIT - initialize a floppy controller.

  Image addresses:
    sau2  0x00E3E002  FLP_$CINIT
    sau4  0x0F845FBC  FLP_$CINIT
    sau7  0x3C44E1A2  FLP_$CINIT
    sau8  0x03C460CA  FLP_$CINIT

  - The driver is registered with DISK only after SPECIFY succeeded.
  - The AT bus form maps the controller's ports first and resets the
    controller through the digital output, with no probe and no drain.
  - The page DMA form (`floppy_page_dma') acquires the interrupt for
    FLP_$INT first (IO_$ACQUIRE on the kind-3 DCTE's request: its failure
    is "not in system") and resets the page's DMA controller before
    draining the controller.

  Returns:
    status_$ok: the controller is initialized
    status_$io_controller_not_in_system: the probe fails
    status_$disk_controller_error: the controller is not drained in 200
      tries
    SHAKE's result: SPECIFY fails
    IO_$MAP_CSR's status: the AT bus form's ports not mapped

  Status stored: none.
}

%if floppy_atbus %then
function flp_$cinit(var dcte: flp_$dcte_t): integer32;
var
  status: status_$t;
  ctlr: pinteger;
  delay: integer;
  i: integer;
begin
  io_$map_csr(dcte.req, status);
  if status.all = status_$ok then begin
    ctlr := dcte.cnum;
    flp_hw_addr := flp_$regs_ptr_t(dcte.req.csr.va);
    flp_ctlr_table[ctlr].dcte := addr(dcte);
    flp_ctlr_table[ctlr].hw_addr := flp_hw_addr;
    ec_$init(flp_$ec);

    { the controller reset }
    with flp_hw_addr^ do begin
      status.all := status_$ok;
      flp_b_1f2 := false;
      flp_$motor_on := false;
      dor := 8;
      for i := 1 to flp_reset_hold do
        delay := delay + 1;
      dor := 16#0C;
      dig_in := 0;
      reg_06 := 2;
    end;

    { SPECIFY, then the registration }
    if status.all = status_$ok then begin
      status.all := shake(flp_specify_cmd, 3, 1);
      if status.all = status_$ok then
        discard(disk_$register(1, ctlr, flp_unit_count, dcte.lock,
                               addr(flp_jump_table)));
    end;
  end;
  flp_$cinit := status.all;
end;
%elseif floppy_page_dma %then
function flp_$cinit(var dcte: flp_$dcte_t): integer32;
var
  status: status_$t;
  sense: pinteger;
  tries: pinteger;
  ctlr: pinteger;
begin
  io_$acquire(dcte.req, addr(flp_$int), addr(dcte), flp_io_unit, status);
  if status.all <> status_$ok then begin
    flp_$cinit := status_$io_controller_not_in_system;
    return;
  end;

  ctlr := dcte.cnum;
  flp_hw_addr := flp_$regs_ptr_t(dcte.req.csr.va);
  flp_ctlr_table[ctlr].dcte := addr(dcte);
  flp_ctlr_table[ctlr].hw_addr := flp_hw_addr;

  ec_$init(flp_$ec);

  { the DMA controller's reset; drain the controller }
  with flp_hw_addr^ do begin
    status.all := status_$ok;
    dma_master_clear := 0;
    dma_command := 16#20;
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
        status.all := status_$disk_controller_error;
        exit;
      end;
    end;
  end;

  { SPECIFY, then the registration }
  if status.all = status_$ok then begin
    status.all := shake(flp_specify_cmd, 3, 1);
    if status.all = status_$ok then
      discard(disk_$register(1, ctlr, flp_unit_count, dcte.lock,
                             addr(flp_jump_table)));
  end;

  flp_$cinit := status.all;
end;
%else

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
%endif
