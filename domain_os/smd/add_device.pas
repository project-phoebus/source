{ SMD_$ADD_DEVICE - add a display device as the next display unit.

  Image addresses:
    sau7  0x3C43E3C4  SMD_$ADD_DEVICE
    sau9  0x3C43B394  SMD_$ADD_DEVICE

  - The unit gets the device's descriptor and routine vector; each nil
    routine of the vector gets the driver's default (an SMD_$NOP_
    routine).
  - n_units counts the device's special segments, numbered from 0 across
    the devices; a device with none gets the nil special UID.
  - More than eight units, or more than eight special segments, crash
    the system with smd_$illegal_unit.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure smd_$add_device(n_units: pinteger; dcte: univ_ptr);
  options(val_param);
var
  vec: smd_dev_vector_ptr_t;
  i: integer32;
  info: smd_dev_info_ptr_t;
  { The vector's defaults, cell by cell (the vector's routines from cell
    1); the nil cell 26, the vector's hw_uid, ends them. }
  default_vector: static smd_dev_cells_t := [
    nil,
    addr(smd_$nop1),                      { shutdown }
    addr(smd_$nop_video),                 { video_ctl }
    addr(smd_$nop1),                      { cold_init }
    addr(smd_$nop_crsr),                  { load_crsr }
    addr(smd_$nop_copy),                  { copy_font }
    addr(smd_$nop_lock),                  { lock_display }
    addr(smd_$nop_blink),                 { blink_cursor }
    addr(smd_$nop_xor),                   { xor_cursor }
    addr(smd_$nop_rel),                   { rel_display }
    addr(smd_$nop_map),                   { map }
    addr(smd_$nop_unmap),                 { unmap }
    addr(smd_$nop2),                      { install_disp }
    addr(smd_$nop_lite),                  { lites }
    addr(smd_$nop_assoc),                 { assoc }
    addr(smd_$nop2),                      { dissoc }
    addr(smd_$nop2),                      { busy_wait }
    addr(smd_$nop1),                      { clear_screen }
    addr(smd_$nop_put),                   { putc }
    addr(smd_$nop_logo),                  { display_logo }
    addr(smd_$nop_color),                 { set_color_table }
    addr(smd_$nop_devinfo),               { device_info }
    addr(smd_$nop_sharedev),              { share_device }
    addr(smd_$nop_fifowait),              { fifo_wait }
    addr(smd_$nop_touch),                 { touch }
    addr(smd_$nop_close),                 { close }
    nil, nil, nil, nil, nil, nil, nil];
  { The next device's first special segment. }
  next_special_seg: static pinteger := 0;
begin
  with smd_$wired_data do begin
    unit_count := unit_count + 1;
    if unit_count > smd_unit_count then
      crash_system(smd_$illegal_unit);
    if next_special_seg + n_units > smd_unit_count then
      crash_system(smd_$illegal_unit);

    unit[unit_count].dcte := dcte;
    vec := smd_dev_dcte_ptr_t(dcte)^.vector;
    unit[unit_count].vector := vec;

    { the defaults for the routines the device has not set }
    i := 1;
    while default_vector[i] <> nil do begin
      if vec^.cells[i] = nil then
        vec^.cells[i] := default_vector[i];
      i := i + 1;
    end;

    info := smd_dev_dcte_ptr_t(dcte)^.info;
    info^.display_uid.high := display1_$uid.high;
    info^.display_uid.low := unit_count;
    if n_units = 0 then
      info^.special_uid := uid_$nil
    else begin
      info^.special_uid.high := special_seg_$uid.high;
      info^.special_uid.low := unit_count;
      info^.special_seg := next_special_seg;
      next_special_seg := next_special_seg + n_units;
    end;
  end;
end;
