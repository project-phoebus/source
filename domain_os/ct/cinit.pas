%if ct_scsi %then
{ CT_$CINIT - the cartridge tape controller's initialization.

  Image addresses:
    sau9  0x3C43BB90  CT_$CINIT

  - The SCSI tape driver has no controller of its own: CT_$CINIT, the
    SCSI_CTAPE_DCTEs' init routine, answers that it is not in the
    system, and CT_$ACQUIRE sets the drive up on the SCSI bus.
  - The frame holds 28 bytes no object addresses besides the result
    (unused_frame and unused_frame_2, stand-ins).

  Returns:
    status_$io_controller_not_in_system

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function ct_$cinit(var dcte: dcte_t): integer32;
var
  unused_frame: array[1..6] of integer32; { a stand-in }
  unused_frame_2: integer32;              { a stand-in }
begin
  ct_$cinit := status_$io_controller_not_in_system;
end;
%elseif ct_atbus_qic02 %then
{ CT_$CINIT - initialize the cartridge tape controller.

  Image addresses:
    sau8  0x03C38FD0  CT_$CINIT

  - With the AT bus adapter (`ct_atbus_qic02'): the driver's
    eventcount is initialized and the DCTE's request's CSR page mapped
    (IO_$MAP_CSR); the adapter's ports and PBU unit are noted.
  - The adapter is reset, held for 3168 counts, and released; it is
    there when its status shows ct_probe_reset within 3168 polls, then
    ct_probe_ready within 132000000.

  Returns:
    0: the adapter answered
    status_$io_controller_not_in_system: it did not

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function ct_$cinit(var dcte: dcte_t): integer32;
type
  req_ptr_t = ^io_$acquire_rec_t;
var
  req: req_ptr_t;
  status: status_$t;
  i: integer32;
  regs: ct_$atbus_regs_ptr_t;
  result: integer32;
  found: boolean;
begin
  ec_$init(ct_ec);
  req := req_ptr_t(dcte.disk_dinit);
  io_$map_csr(req^, status);
  ct_regs := ct_$atbus_regs_ptr_t(req^.csr.va);
  ct_pbu_unit := req^.int.id.vector;
  regs := ct_regs;
  result := status_$io_controller_not_in_system;
  regs^.dma_reset := 0;
  regs^.ctl := ct_ctl_reset;
  for i := 1 to 3168 do
    ;
  regs^.ctl := 0;
  found := false;
  for i := 1 to 3168 do
    if regs^.ctl = ct_probe_reset then begin
      found := true;
      exit;
    end;
  if found then
    for i := 1 to 132000000 do
      if regs^.ctl = ct_probe_ready then begin
        result := 0;
        exit;
      end;
  ct_$cinit := result;
end;
%else
{ CT_$CINIT - the cartridge tape controller's initialization.

  Image addresses:
    sau5  0x00E3745C  CT_$CINIT

  - The DCTE and the controller's window are noted, the module's
    eventcount initialized, and the window probed (ct_probe_word at
    +0x300, TESTPAGE kind 3).
  - A controller that answers has its byte at 7 cleared.

  Returns:
    0: the controller answered
    status_$io_controller_not_in_system: it did not

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function ct_$cinit(var dcte: dcte_t): integer32;
var
  probe_word: integer;
  probe: univ_ptr;
begin
  ct_dcte := addr(dcte);
  ct_regs := dcte.disk_dinit;
  probe_word := ct_probe_word;
  ec_$init(ct_ec);
  probe := addr(ct_regs^.config);
  if not testpage(3, probe, probe_word) then
    ct_$cinit := status_$io_controller_not_in_system
  else begin
    ct_regs^.ctl_07 := 0;
    ct_$cinit := 0;
  end;
end;
%endif
