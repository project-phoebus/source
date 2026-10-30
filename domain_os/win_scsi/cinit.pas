{ WIN_SCSI_$CINIT - the controller initialization: find a SCSI disk at a
  DCTE's controller number and register the driver for it.

  Image addresses:
    sau9  0x3C4361A0  WIN_SCSI_$CINIT

  - Acquires the target (SCSI_$SETUP), sends RESERVE (again after a unit
    attention) and INQUIRY; a disk's vendor, product and revision go to
    logical unit 0, and the driver is registered with DISK_$REGISTER
    (the DCTE's lock number, the jump table).
  - The target is released again (RELEASE, SCSI_$RELEASE) whenever it
    was acquired: DINIT acquires it for good.
  - Only bits 9..15 of the registration word are set.

  Status stored:
    status_$ok: a disk answered and the driver is registered
    status_$disk_driver_logic_error: the controller number is above 8
    status_$unrecognized_drive_id: the device is not a disk
    SCSI_$SETUP's or a command's status
}

[section(os_init_proc, os_init_data)]
function win_scsi_$cinit(var dcte: dcte_t): integer32;
label
  done;
var
  acquired: boolean;
  status: status_$t;
  rel_status: status_$t;
  u: win_scsi_unit_ptr_t;
  bus: integer;
  target: integer;
  handle: scsi_$handle_t;
  reg: win_scsi_reg_word_t;
  cdb: scsi_$cdb_t;
  inq: win_scsi_inquiry_data_t;
  i: integer;
begin
  acquired := false;
  status.all := status_$ok;
  if dcte.cnum > win_scsi_max_ctlr then begin
    status.all := status_$disk_driver_logic_error;
    goto done;
  end;
  u := addr(win_scsi_units[dcte.cnum]);
  bus := dcte.cnum div 8;
  target := dcte.cnum mod 8;
  scsi_$setup(bus, target, handle, status);
  acquired := status.all = status_$ok;
  if status.all <> status_$ok then
    goto done;
  u^.handle := handle;
  reg.bits := reg.bits + [15];
  reg.bits := reg.bits - [14, 12];
  reg.bits := reg.bits + [13, 11];
  reg.bits := reg.bits - [10];
  reg.bits := reg.bits + [9];
  u^.buf_ptr := addr(u^.buf);
  u^.max_pages := win_scsi_max_pages;

  { RESERVE, again after a unit attention. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.op := win_scsi_op_reserve;
  cdb.f.lun := 0;
  status.all := win_scsi_command(u^.handle, addr(u^.luns[0]), cdb, 0,
                                 scsi_$dir_out, nil, 0, win_scsi_timeout);
  if status.all = status_$disk_unit_attention then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.op := win_scsi_op_reserve;
    cdb.f.lun := 0;
    status.all := win_scsi_command(u^.handle, addr(u^.luns[0]), cdb, 0,
                                   scsi_$dir_out, u^.buf_ptr, 0,
                                   win_scsi_timeout);
  end;
  if status.all <> status_$ok then
    goto done;

  { INQUIRY. }
  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.op := win_scsi_op_inquiry;
  cdb.f.lun := 0;
  cdb.b[4] := chr(36);
  status.all := win_scsi_command(u^.handle, addr(u^.luns[0]), cdb, 0,
                                 scsi_$dir_in, addr(inq), ord(cdb.b[4]),
                                 win_scsi_timeout);
  if status.all <> status_$ok then
    goto done;
  if inq.f.dev_type <> 0 then begin
    status.all := status_$unrecognized_drive_id;
    goto done;
  end;
  u^.luns[0].vendor := inq.vendor;
  u^.luns[0].product := inq.product;
  u^.luns[0].revision := inq.revision;
  if status.all = status_$ok then begin
    u^.lock := dcte.disk_error_que_hi;
    discard(disk_$register(0, dcte.cnum, reg.all, u^.lock,
                           addr(win_scsi_jump_table)));
  end;

done:
  with win_scsi_units[dcte.cnum] do
    if acquired then begin
      for i := 0 to 5 do
        cdb.b[i] := chr(0);
      cdb.f.op := win_scsi_op_release;
      cdb.f.lun := 0;
      rel_status.all := win_scsi_command(handle, addr(luns[0]), cdb, 0,
                                         scsi_$dir_out, nil, 0,
                                         win_scsi_timeout);
      scsi_$release(handle, rel_status);
    end;
  win_scsi_$cinit := status.all;
end;
