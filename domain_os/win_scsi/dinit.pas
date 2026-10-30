{ WIN_SCSI_$DINIT - the unit initialization entry: bring a SCSI disk up
  and find its size and geometry.

  Image addresses:
    sau9  0x3C41BA48  WIN_SCSI_$DINIT

  - Under the controller's lock: acquires the target (SCSI_$SETUP), makes
    it a system device, then RESERVE, INQUIRY, PREVENT MEDIUM REMOVAL for
    a removable medium, START UNIT, TEST UNIT READY (the RESERVE, the
    START and the TEST again after a unit attention), READ CAPACITY, the
    format device and rigid disk geometry pages, the error recovery page
    set and checked, and the SCSI driver's limits.
  - num_blocks above 0 is the caller's size: the geometry pages are not
    asked for, nor the size returned.  A fixed disk without either page
    crashes the system (win_scsi_no_geometry); a removable one gets 17
    sectors on one head, or one head.
  - flags is the size in units of 10 MB plus 16#700, at most 16#7FF
    (else 16#700).
  - On a failure after the system device was set the target is released
    (RELEASE, SCSI_$RELEASE); the unit is ready only on success.

  Status stored:
    status_$ok: the unit is ready
    status_$invalid_unit_number: unit is not 0
    status_$disk_driver_logic_error: ctlr above 8, a device other than a
      disk, or an unknown SCSI driver version
    SCSI_$SETUP's, SCSI_$SET_SYS_DEVICE's or a command's status
}

function win_scsi_$dinit(unit: integer; ctlr: pinteger;
                         var num_blocks: integer32;
                         var sec_per_track: pinteger;
                         var num_heads: pinteger;
                         out label_info: win_scsi_label_info_t;
                         out flags: win_scsi_dev_flags_t): integer32;
label
  done;
var
  locked: boolean;
  sys_device: boolean;
  no_format_page: boolean;
  no_geometry_page: boolean;
  status: status_$t;
  rel_status: status_$t;
  handle: scsi_$handle_t;
  bus: integer;
  target: integer;
  u: win_scsi_unit_ptr_t;
  lr: win_scsi_lun_ptr_t;
  cdb: scsi_$cdb_t;
  i: integer;
  inq: win_scsi_inquiry_ptr_t;
  cap: win_scsi_capacity_ptr_t;
  mh: win_scsi_mode_hdr_ptr_t;
  pg: win_scsi_page_ptr_t;
  blocks: linteger;
  cylinders: linteger;
  info: scsi_$info_t;
begin
  locked := false;
  if unit <> 0 then begin
    status.all := status_$invalid_unit_number;
    goto done;
  end;
  if ctlr > win_scsi_max_ctlr then begin
    status.all := status_$disk_driver_logic_error;
    goto done;
  end;
  ml_$lock(win_scsi_units[ctlr].lock);
  locked := true;
  u := addr(win_scsi_units[ctlr]);
  lr := addr(u^.luns[unit]);
  sys_device := false;

  { The target. }
  bus := ctlr div 8;
  target := ctlr mod 8;
  scsi_$setup(bus, target, handle, status);
  if status.all <> status_$ok then
    goto done;
  scsi_$set_sys_device(handle, univ_ptr(addr(win_scsi_$do_sys_command)),
                       status);
  if status.all <> status_$ok then
    goto done;
  sys_device := true;
  u^.handle := handle;

  { RESERVE, again after a unit attention. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.op := win_scsi_op_reserve;
  cdb.f.lun := unit;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                 nil, 0, win_scsi_timeout);
  if status.all = status_$storage_module_stopped then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.op := win_scsi_op_reserve;
    cdb.f.lun := unit;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                   nil, 0, win_scsi_timeout);
  end;
  if status.all <> status_$ok then
    goto done;

  { INQUIRY: the removable bit and the ANSI version; a failure is let
    pass. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := unit;
  cdb.f.op := win_scsi_op_inquiry;
  cdb.b[4] := chr(36);
  lr^.removable := false;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_in,
                                 u^.buf_ptr, ord(cdb.b[4]),
                                 win_scsi_timeout);
  if status.all = status_$ok then begin
    inq := u^.buf_ptr;
    lr^.removable := inq^.rmb;
    lr^.ansi_version := inq^.ansi;
    if inq^.dev_type <> 0 then begin
      status.all := status_$disk_driver_logic_error;
      goto done;
    end;
  end;

  { PREVENT MEDIUM REMOVAL; a device without it is let pass. }
  if lr^.removable then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.op := win_scsi_op_prevent_allow;
    cdb.g0.start := true;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                   nil, 0, win_scsi_timeout);
    if status.all = status_$disk_illegal_request_for_device then
      status.all := status_$ok;
    if status.all <> status_$ok then
      goto done;
  end;

  { START UNIT, again after a unit attention. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.op := win_scsi_op_start_stop_unit;
  cdb.f.lun := unit;
  cdb.g0.start := true;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                 nil, 0, win_scsi_start_timeout);
  if status.all = status_$disk_unit_attention then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.lun := unit;
    cdb.f.op := win_scsi_op_start_stop_unit;
    cdb.g0.start := true;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                   nil, 0, win_scsi_timeout);
  end;
  if (status.all <> status_$ok)
     and then (status.all <> status_$disk_illegal_request_for_device) then
    goto done;

  { TEST UNIT READY, again after a unit attention. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := unit;
  cdb.f.op := win_scsi_op_test_unit_ready;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                 nil, 0, win_scsi_timeout);
  if status.all = status_$disk_unit_attention then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.lun := unit;
    cdb.f.op := win_scsi_op_test_unit_ready;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                   nil, 0, win_scsi_timeout);
  end;
  if status.all <> status_$ok then
    goto done;

  { READ CAPACITY: the block size, the size in 1024-byte blocks and the
    flags. }
  for i := 0 to 9 do
    cdb.b[i] := chr(0);
  cdb.f.lun := unit;
  cdb.f.op := win_scsi_op_read_capacity;
  cap := u^.buf_ptr;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_in,
                                 u^.buf_ptr, 8, win_scsi_timeout);
  if status.all <> status_$ok then
    goto done;
  lr^.block_len := cap^.block_len;
  blocks := cap^.last_block * cap^.block_len;
  flags.all := blocks div 10485760;
  blocks := blocks div win_scsi_block_size;
  flags.class := flags.class + 7;
  if flags.all > 16#7FF then
    flags.all := 16#700;

  { The format device page: the sectors per track and the bytes in a
    sector. }
  no_format_page := false;
  mh := u^.buf_ptr;
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.lun := unit;
  cdb.f.op := win_scsi_op_mode_sense;
  cdb.b[4] := chr(255);
  cdb.g0.pc := 0;
  cdb.g0.page := win_scsi_format_device_page;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_in,
                                 u^.buf_ptr, ord(cdb.b[4]),
                                 win_scsi_timeout);
  if status.all = status_$disk_illegal_request_for_device then begin
    if num_blocks <= 0 then begin
      no_format_page := true;
      if not lr^.removable then
        crash_system(win_scsi_no_geometry);
    end;
  end
  else begin
    if status.all <> status_$ok then
      goto done;
    pg := univ_ptr(ord(mh^.bd_len) + integer32(u^.buf_ptr) + 4);
    if num_blocks <= 0 then begin
      sec_per_track := pg^.sec_per_track;
      label_info[0] := 0;
      label_info[1] := pg^.sector_bytes;
      if sec_per_track = 0 then
        no_format_page := true;
    end;
  end;

  { The rigid disk geometry page: the heads and the cylinders. }
  no_geometry_page := false;
  if num_blocks <= 0 then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.lun := unit;
    cdb.f.op := win_scsi_op_mode_sense;
    cdb.b[4] := chr(255);
    cdb.g0.pc := 0;
    cdb.g0.page := win_scsi_rigid_geometry_page;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_in,
                                   u^.buf_ptr, ord(cdb.b[4]),
                                   win_scsi_timeout);
    if status.all = status_$disk_illegal_request_for_device then begin
      no_geometry_page := true;
      if not lr^.removable then
        crash_system(win_scsi_no_geometry);
    end
    else begin
      if status.all <> status_$ok then
        goto done;
      pg := univ_ptr(ord(mh^.bd_len) + integer32(u^.buf_ptr) + 4);
      num_heads := pg^.geom.heads;
      cylinders := pg^.geom.cylinders;
    end;
  end;

  { The geometry the pages did not give, and the size rounded to it. }
  if no_format_page then begin
    label_info[0] := 0;
    label_info[1] := lr^.block_len;
    if no_geometry_page then begin
      sec_per_track := 17;
      num_heads := 1;
      blocks := (blocks div 17) * 17;
    end
    else begin
      sec_per_track := blocks div (num_heads * cylinders);
      blocks := sec_per_track * cylinders * num_heads;
    end;
  end
  else if no_geometry_page then begin
    num_heads := 1;
    blocks := (blocks div sec_per_track) * sec_per_track;
  end;

  { The error recovery page, then the driver's limits. }
  status.all := win_scsi_set_error_page(u, lr, unit, cdb, false, false);
  if lr^.removable
     and then (status.all = status_$disk_illegal_request_for_device) then
    status.all := win_scsi_set_error_page(u, lr, unit, cdb, false, true);
  if status.all <> status_$ok then
    goto done;
  status.all := win_scsi_check_error_page(u, lr, unit);
  if status.all <> status_$ok then
    goto done;
  scsi_$get_info(u^.handle, 8, info, status);
  if info.version <> 1 then begin
    status.all := status_$disk_driver_logic_error;
    goto done;
  end;
  if u^.max_pages * win_scsi_block_size > info.max_transfer then
    u^.max_pages := info.max_transfer div win_scsi_block_size;
  if num_blocks <= 0 then
    num_blocks := blocks;

done:
  if sys_device then
    win_scsi_units[ctlr].ready := status.all = status_$ok;
  if sys_device and then (status.all <> status_$ok) then
    with win_scsi_units[ctlr] do begin
      for i := 0 to 5 do
        cdb.b[i] := chr(0);
      cdb.f.op := win_scsi_op_release;
      cdb.f.lun := unit;
      rel_status.all := win_scsi_command(handle, addr(luns[unit]), cdb,
                                         unit, scsi_$dir_out, nil, 0,
                                         win_scsi_timeout);
      scsi_$release(handle, rel_status);
    end;
  win_scsi_$dinit := status.all;
  if locked then
    ml_$unlock(win_scsi_units[ctlr].lock);
end;
