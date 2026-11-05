{ MONO_$IOINIT - find and set up a MONO board at boot.

  Image addresses:
    sau7  0x3C43EEA8  MONO_$IOINIT
    sau8  0x03C38DE4  MONO_$IOINIT

  - A unit whose state another descriptor has claimed already (its
    display UID set) is not there.
  - The CSR pages and the display memory are each mapped (IO_$MAP_CSR)
    unless already mapped where their bus addresses say.
  - The board is there when its identification byte is the vector's
    display type and the display memory keeps a probe; then a second
    controller's display memory is cleared and the driver gets the unit
    (SMD_$ADD_DEVICE).
  - On a failure what was mapped here is unmapped.

  Status stored (the result):
    status_$ok: the board is there
    status_$io_controller_not_in_system: the state claimed, a page mapped
      elsewhere, or no board
    MMU_$VTOP's or IO_$MAP_CSR's status: a request could not be mapped
}

[section(os_init_proc, os_init_data)]
function mono_$ioinit(var dcte: mono_$dcte_t): integer32;
label
  fail;
var
  hdm: mono_$hdm_ptr_t;
  info: mono_$info_ptr_t;
  status: status_$t;
  config: mono_$req_ptr_t;
  csr: mono_$req_ptr_t;
  phys: integer32;
  ppn: integer32;
  mapped: mono_$mapped_set_t;
  regs: mono_$regs_ptr_t;
  id: integer;
  probe: mono_$probe_ptr_t;
begin
  status.all := status_$ok;
  hdm := dcte.hdm;
  info := dcte.info;
  config := dcte.config;
  csr := mono_$req_ptr_t(config^.unused_00);
  if info^.display_uid <> uid_$nil then
    goto fail;
  info^.regs := mono_$regs_ptr_t(csr^.csr.va);
  info^.csr_ppn := atbus_$xlate_iova(csr^.csr.pa);
  mapped := [];

  { the CSR pages: mapped here, or already at their bus address }
  ppn := mmu_$vtop(integer32(info^.regs), status);
  if status.all <> status_$ok then begin
    io_$map_csr(csr^, status);
    if status.all <> status_$ok then
      goto fail;
    mapped := [mono_$csr_mapped];
  end
  else if ppn <> info^.csr_ppn then
    goto fail;

  { the display memory: the same }
  phys := atbus_$xlate_iova(config^.csr.pa);
  ppn := mmu_$vtop(config^.csr.va, status);
  if status.all <> status_$ok then begin
    io_$map_csr(config^, status);
    if status.all <> status_$ok then
      goto fail;
    mapped := mapped + [mono_$memory_mapped];
  end
  else if ppn <> phys then
    goto fail;
  info^.memory := config^.csr.va;

  { the registers' first settings }
  regs := info^.regs;
  regs^.reg_400 := 16#E0;
  regs^.mask := 0;
  regs^.ctl.flags := 16#8B;
  regs^.reg_404.all := 16#C0;

  { the board and its memory }
  if regs^.board.id <> hdm^.disp_type then
    goto fail;
  probe := mono_$probe_ptr_t(info^.memory);
  probe^ := mono_$memory_probe;
  id := regs^.board.id;
  if probe^ <> mono_$memory_probe then
    goto fail;
  if dcte.cnum <> 0 then
    os_$data_zero(probe^, rshft(hdm^.line_bits * hdm^.word_74, 3));
  smd_$add_device(1, addr(dcte));
  mono_$ioinit := status_$ok;
  return;

fail:
  if status.all = status_$ok then
    mono_$ioinit := status_$io_controller_not_in_system
  else
    mono_$ioinit := status.all;
  if mono_$csr_mapped in mapped then
    io_$unmap_csr(mono_$req_ptr_t(config^.unused_00)^, status);
  if mono_$memory_mapped in mapped then
    io_$unmap_csr(config^, status);
end;
