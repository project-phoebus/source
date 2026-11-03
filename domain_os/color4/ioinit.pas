{ COLOR4_$IOINIT - find and set up a COLOR4 board at boot.

  Image addresses:
    sau8  0x03C388FC  COLOR4_$IOINIT

  - The CSR pages and the display memory are each mapped (IO_$MAP_CSR)
    unless already mapped where their bus addresses say.
  - The board is there when its identification byte is the vector's
    display type and the display memory keeps a probe; then the driver
    gets the unit (SMD_$ADD_DEVICE), the unit at the lookup-table CSR
    address gets a ramp in its table, and the display memory is
    cleared.
  - On a failure what was mapped here is unmapped.

  Status stored (the result):
    status_$ok: the board is there
    status_$io_controller_not_in_system: a page mapped elsewhere, or no
      board
    MMU_$VTOP's or IO_$MAP_CSR's status: a request could not be mapped
}

[section(os_init_proc, os_init_data)]
function color4_$ioinit(var dcte: color4_$dcte_t): integer32;
label
  fail;
var
  ramp: static color4_$ramp_t :=
    [16#00, 16#1F, 16#2F, 16#3F, 16#4F, 16#5F, 16#6F, 16#7F,
     16#8F, 16#9F, 16#AF, 16#BF, 16#CF, 16#DF, 16#EF, 16#FF];  { +0x0 }
  hdm: color4_$hdm_ptr_t;
  info: color4_$info_ptr_t;
  status: status_$t;
  config: color4_$req_ptr_t;
  csr: color4_$req_ptr_t;
  phys: integer32;
  ppn: integer32;
  regs: color4_$regs_ptr_t;
  mapped: color4_$mapped_set_t;
  id: integer;
  probe: color4_$probe_ptr_t;
  i: integer;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  hdm := dcte.hdm;
  info := dcte.info;
  config := dcte.config;
  csr := color4_$req_ptr_t(config^.unused_00);
  info^.regs := color4_$regs_ptr_t(csr^.csr.va);
  info^.csr_ppn := atbus_$xlate_iova(csr^.csr.pa);
  mapped := [];

  { the CSR pages: mapped here, or already at their bus address }
  ppn := mmu_$vtop(integer32(info^.regs), status);
  if status.all <> status_$ok then begin
    io_$map_csr(csr^, status);
    if status.all <> status_$ok then
      goto fail;
    mapped := [color4_$csr_mapped];
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
    mapped := mapped + [color4_$memory_mapped];
  end
  else if ppn <> phys then
    goto fail;
  info^.memory := config^.csr.va;

  { the registers' first settings }
  regs := info^.regs;
  if csr^.csr.pa = color4_$lut_unit_csr then begin
    regs^.reg_406 := 16#80;
    regs^.ctl.flags := 16#8B;
  end;
  regs^.reg_400 := 16#E0;
  regs^.mask := 0;
  regs^.ctl.flags := 16#8B;
  regs^.reg_404 := 16#C0;

  { the board and its memory }
  if regs^.board.id <> hdm^.disp_type then
    goto fail;
  probe := color4_$probe_ptr_t(info^.memory);
  probe^ := color4_$memory_probe;
  id := regs^.board.id;
  if probe^ <> color4_$memory_probe then
    goto fail;
  smd_$add_device(1, addr(dcte));

  { the ramp, once the table can be loaded }
  if csr^.csr.pa = color4_$lut_unit_csr then begin
    repeat
    until regs^.board.flag_8;
    for i := 0 to color4_$lut_entries - 1 do begin
      regs^.lut_red := ramp[i];
      regs^.ctl.lut_green := ramp[i];
      regs^.lut_blue := ramp[i];
    end;
  end;

  { the display memory cleared }
  for row := 0 to hdm^.word_74 - 1 do
    for col := 0 to hdm^.line_bits div 16 - 1 do
      color4_$memory_ptr_t(info^.memory)^[row, col] := 0;
  color4_$ioinit := status_$ok;
  return;

fail:
  if status.all = status_$ok then
    color4_$ioinit := status_$io_controller_not_in_system
  else
    color4_$ioinit := status.all;
  if color4_$csr_mapped in mapped then
    io_$unmap_csr(color4_$req_ptr_t(color4_$req_ptr_t(dcte.config)^.unused_00)^,
                  status);
  if color4_$memory_mapped in mapped then
    io_$unmap_csr(color4_$req_ptr_t(dcte.config)^, status);
end;
