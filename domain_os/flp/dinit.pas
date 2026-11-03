{ FLP_$DINIT - initialize a floppy drive.

  Image addresses:
    sau2  0x00E3E112  FLP_$DINIT
    sau4  0x0F8460DE  FLP_$DINIT
    sau8  0x03C461A6  FLP_$DINIT

  - The FORMAT TRACK table's page is wired the first time.
  - The geometry and the label come back only when the recalibrate
    succeeded and num_blocks was not positive; the label's word at 6 is
    set to 1 on every path.
  - The page DMA form puts the FORMAT TRACK table's page in IOMAP's
    entry 0 and keeps its offset as the DMA address bytes.

  Returns:
    status_$invalid_unit_number: the unit is above 3
    the recalibrate's status: otherwise

  Status stored: none.
}

{ TODO(pascal) FLP_$DINIT's label record copied from a constant in the code

  pvlabel_info is filled by a block copy from the 10 bytes after the
  routine's code, laid out with the routine's other cell as a by-address
  constant would be: so a 10-byte constant of the record's size assigned
  to it.  The reference has no record constants (no structured constant
  in a `const' part, no constructor; dpc refuses `r(...)' and `chr(..) +
  ..' alike), and a string constant cannot hold these bytes; a `static'
  variable would be in the data section, not the code.  The Pascal
  assigns the four fields (the same values; four stores in the code, not
  a copy). }

%if floppy_atbus %then
function flp_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; out num_heads: pinteger;
                    out pvlabel_info: flp_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(val_param);
var
  excs_vol: disk_$volume_t;
  status: status_$t;
  ppn: integer32;
  count: integer;
  i: integer;
begin
  if unit > 3 then begin
    flp_$dinit := status_$invalid_unit_number;
    return;
  end;

  flp_hw_addr := flp_ctlr_table[ctlr].hw_addr;
  if flp_unit_active[unit] then begin
    flp_$dinit := status_$disk_already_mounted;
    return;
  end;
  flp_unit_active[unit] := true;

  { only the first drive sets the controller up }
  count := 0;
  for i := 0 to 3 do
    if flp_unit_active[i] then
      count := count + 1;
  if count > 1 then begin
    flp_$dinit := status_$ok;
    return;
  end;

  { once, the overrun page }
  if flp_need_ovrrun_page then begin
    wp_$calloc(flp_ovrrun_ppn, status);
    if status.all <> status_$ok then
      crash_system(status);
    flp_ovrrun_va := addr(flp_ovrrun_page);
    mmu_$install(flp_ovrrun_ppn, flp_ovrrun_va, 0, 16#16);
    flp_ovrrun_last := flp_$long_ptr_t(integer32(flp_ovrrun_va) + 16#3FC);
    flp_need_ovrrun_page := false;
  end;

  { once, the FORMAT TRACK table's page }
  if not flp_fmt_ready then begin
    ppn := mmu_$vtop(integer32(addr(flp_io_buffer)), status);
    wp_$wire(ppn);
    flp_fmt_buf_pa := lshft(ppn, 10) +
                      (integer32(addr(flp_io_buffer)) & 16#3FF);
    flp_fmt_ready := true;
  end;

  { the interrupt }
  io_$acquire(flp_ctlr_table[ctlr].dcte^.req, addr(flp_$int),
              flp_ctlr_table[ctlr].dcte, flp_io_unit, status);
  if status.all <> status_$ok then begin
    flp_$dinit := status.all;
    return;
  end;
  excs_vol.as_options := [];
  flp_fmt_buf_pa2 := flp_fmt_buf_pa;
  flp_hw_addr^.dor := 16#0C;
  io_$enable_device(flp_io_unit, status);
  if status.all <> status_$ok then begin
    flp_$dinit := status.all;
    io_$release(flp_io_unit, status);
    return;
  end;

  { the controller reset, SPECIFY, the motor }
  with flp_hw_addr^ do begin
    flp_$motor_on := false;
    dor := 8;
    for i := 1 to 100 do
      flp_delay := flp_delay + 1;
    dor := 16#0C;
    dig_in := 0;
    reg_06 := 2;
  end;
  discard(shake(flp_specify_cmd, 3, 1));
  flp_$turn_motor_on;

  { a seek to cylinder 2, then recalibrate (twice if need be) }
  flp_rw_cmd[1] := unit;
  flp_rw_cmd[2] := 2;
  flp_rw_cmd[3] := 2;
  flp_rw_cmd[4] := 1;
  flp_rw_cmd[0] := 16#0F;
  discard(excs(flp_rw_cmd, 3, excs_vol));
  flp_cmd_retry := 0;
  flp_recal_cmd[1] := unit;
  status.all := excs(flp_recal_cmd, 2, excs_vol);
  if status.all <> status_$ok then
    status.all := excs(flp_recal_cmd, 2, excs_vol);

  flp_unit_cyl[unit] := 0;
  flp_disk_change[unit] := false;

  { the geometry }
  if (status.all = status_$ok) and then (num_blocks <= 0) then begin
    flags := 0;
    sec_per_track := 8;
    num_heads := 2;
    num_blocks := 1232;
    pvlabel_info.l_00 := 16#9204B2;
    pvlabel_info.w_04 := 0;
    pvlabel_info.w_06 := 1;
    pvlabel_info.w_08 := 0;
  end;

  pvlabel_info.w_06 := 1;
  flp_$dinit := status.all;
end;
%else

function flp_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; out num_heads: pinteger;
                    out pvlabel_info: flp_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(val_param);
var
  excs_vol: disk_$volume_t;
  ppn: integer32;
  status: status_$t;
%if floppy_page_dma %then
  offset: integer32;
%endif
  unused_54: integer32;                   { stand-in }
  unused_58: integer32;                   { stand-in }
begin
  if unit > 3 then begin
    flp_$dinit := status_$invalid_unit_number;
    return;
  end;

  flp_hw_addr := flp_ctlr_table[ctlr].hw_addr;

  { once, the FORMAT TRACK table's page }
  if not flp_initialized then begin
    ppn := mmu_$vtop(integer32(addr(flp_io_buffer)), status);
    wp_$wire(ppn);
%if floppy_page_dma %then
    offset := integer32(addr(flp_io_buffer)) & 16#3FF;
    flp_fmt_addr_lo := offset;
    flp_fmt_addr_hi := rshft(offset, 8);
    iomap[0] := ppn;
%else
    flp_fmt_buf_pa := lshft(ppn, 10) +
                      (integer32(addr(flp_io_buffer)) & 16#3FF);
%endif
    flp_initialized := true;
  end;

  { recalibrate }
%if not floppy_page_dma %then
  flp_hw_addr^.control := 3;
%endif
  excs_vol.as_options := [];
  flp_cmd_retry := 0;
  flp_recal_cmd[1] := unit;
  status.all := excs(flp_recal_cmd, 2, excs_vol);

  flp_unit_cyl[unit] := 0;
  flp_disk_change[unit] := false;

  { the geometry }
  if (status.all = status_$ok) and then (num_blocks <= 0) then begin
    flags := 0;
    sec_per_track := 8;
    num_heads := 2;
    num_blocks := 1232;
    pvlabel_info.l_00 := 16#9204B2;
    pvlabel_info.w_04 := 0;
    pvlabel_info.w_06 := 1;
    pvlabel_info.w_08 := 0;
  end;

  pvlabel_info.w_06 := 1;
  flp_$dinit := status.all;
end;
%endif
