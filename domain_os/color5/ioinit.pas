{ COLOR5_$IOINIT - find and set up a COLOR5 board at boot.

  Image addresses:
    sau7  0x3C43EBF8  COLOR5_$IOINIT
    sau8  0x03C38B34  COLOR5_$IOINIT

  - The CSR pages and the display memory are each mapped (IO_$MAP_CSR)
    unless already mapped where their bus addresses say.
  - The board is there when its identification byte is the vector's
    display type; the unit at the setup CSR address then gets its
    registers' settings and its display memory cleared, and the driver
    gets the unit (SMD_$ADD_DEVICE) with nothing saved under the cursor.
  - On a failure what was mapped here is unmapped.

  Status stored (the result):
    status_$ok: the board is there
    status_$io_controller_not_in_system: a page mapped elsewhere, or no
      board
    MMU_$VTOP's or IO_$MAP_CSR's status: a request could not be mapped
}

[section(os_init_proc, os_init_data)]
function color5_$ioinit(var dcte: color5_$dcte_t): integer32;
label
  fail;
var
  hdm: color5_$hdm_ptr_t;
  info: color5_$info_ptr_t;
  status: status_$t;
  config: color5_$req_ptr_t;
  memory: color5_$req_ptr_t;
  phys: integer32;
  ppn: integer32;
  mapped: color5_$mapped_set_t;
  i: integer;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  hdm := dcte.hdm;
  info := dcte.info;
  config := dcte.config;
  memory := color5_$req_ptr_t(config^.unused_00);
  info^.regs := color5_$regs_ptr_t(config^.csr.va);
  info^.csr_ppn := atbus_$xlate_iova(config^.csr.pa);
  mapped := [];

  { the CSR pages: mapped here, or already at their bus address }
  ppn := mmu_$vtop(integer32(info^.regs), status);
  if status.all <> status_$ok then begin
    io_$map_csr(config^, status);
    if status.all <> status_$ok then
      goto fail;
    mapped := [color5_$csr_mapped];
  end
  else if ppn <> info^.csr_ppn then
    goto fail;

  { the display memory: the same }
  phys := atbus_$xlate_iova(memory^.csr.pa);
  ppn := mmu_$vtop(memory^.csr.va, status);
  if status.all <> status_$ok then begin
    io_$map_csr(memory^, status);
    if status.all <> status_$ok then
      goto fail;
    mapped := mapped + [color5_$memory_mapped];
  end
  else if ppn <> phys then
    goto fail;

  { the board }
  if info^.regs^.board.id <> hdm^.disp_type then
    goto fail;
  info^.memory := color5_$req_ptr_t(config^.unused_00)^.csr.va;

  { the setup unit's registers, and its display memory cleared }
  if config^.csr.pa = color5_$setup_unit_csr then begin
    info^.regs^.reg_406 := 16#80;
    info^.regs^.ctl.flags := 16#8B;
    info^.regs^.reg_400 := 16#E0;
    info^.regs^.mask := 0;
    info^.regs^.word_002 := 16#3333;
    info^.regs^.word_004 := 16#3333;
    info^.regs^.reg_404 := 0;
    info^.regs^.reg_407 := 16#80;
    info^.regs^.reg_405 := 16#C0;
    info^.regs^.ctl.reg_403 := 16#B8;
    info^.regs^.reg_401 := 16#06;
    info^.regs^.ctl.reg_403 := 16#BA;
    info^.regs^.reg_401 := 16#40;
    info^.regs^.ctl.reg_403 := 16#FC;
    info^.regs^.ctl.reg_403 := 16#B8;
    info^.regs^.reg_401 := 16#05;
    info^.regs^.ctl.reg_403 := 16#BA;
    info^.regs^.reg_401 := 0;
    info^.regs^.ctl.reg_403 := 16#FC;
    info^.regs^.ctl.reg_403 := 16#B8;
    info^.regs^.reg_401 := 16#04;
    info^.regs^.ctl.reg_403 := 16#BA;
    info^.regs^.reg_401 := 16#FF;
    info^.regs^.reg_401 := 16#FC;
    info^.regs^.ctl.reg_403 := 16#E8;
    info^.regs^.ctl.reg_403 := 16#FC;
    info^.regs^.ctl.reg_403 := 16#D8;
    info^.regs^.reg_401 := 0;
    info^.regs^.reg_401 := 0;
    info^.regs^.reg_401 := 0;
    for i := 1 to color5_$fill_count do begin
      info^.regs^.reg_401 := 16#FF;
      info^.regs^.reg_401 := 16#FF;
      info^.regs^.reg_401 := 16#FF;
    end;
    info^.regs^.ctl.reg_403 := 16#B8;
    info^.regs^.reg_401 := 0;
    info^.regs^.ctl.reg_403 := 16#F9;
    info^.regs^.ctl.reg_403 := 16#F1;
    info^.regs^.ctl.reg_403 := 16#F9;
    while info^.regs^.board.flag_8 do
      ;
    info^.regs^.ctl.reg_403 := 16#FC;
    for row := 0 to hdm^.word_74 - 1 do
      for col := 0 to hdm^.line_bits div 16 - 1 do
        color5_$memory_ptr_t(info^.memory)^[row, col] := 0;
  end;

  { nothing saved under the cursor }
  info^.saved_column := 0;
  info^.saved_line := 0;
  info^.saved_size.width := 0;
  info^.saved_size.height := 0;
  smd_$add_device(1, addr(dcte));
  color5_$ioinit := status_$ok;
  return;

fail:
  if status.all = status_$ok then
    color5_$ioinit := status_$io_controller_not_in_system
  else
    color5_$ioinit := status.all;
  if color5_$csr_mapped in mapped then
    io_$unmap_csr(config^, status);
  if color5_$memory_mapped in mapped then
    io_$unmap_csr(color5_$req_ptr_t(config^.unused_00)^, status);
end;
