{ WIN_SCSI_$SHUTDOWN - the shutdown entry: give a ready unit up.

  Image addresses:
    sau9  0x3C41C69A  WIN_SCSI_$SHUTDOWN

  - Only unit 0 of a controller 0..8 that DINIT made ready: a removable
    medium is allowed out again (PREVENT ALLOW MEDIUM REMOVAL, allow),
    the target is released (RELEASE, then SCSI_$RELEASE) and the unit
    no longer ready.
  - The commands' statuses are not looked at.
}

procedure win_scsi_$shutdown(ctlr: pinteger; unit: integer);
var
  u: win_scsi_unit_ptr_t;
  lr: win_scsi_lun_ptr_t;
  cdb: scsi_$cdb_t;
  i: integer;
  status: status_$t;
begin
  if unit <> 0 then
    return;
  if ctlr > win_scsi_max_ctlr then
    return;
  u := addr(win_scsi_units[ctlr]);
  lr := addr(u^.luns[unit]);
  if not u^.ready then
    return;

  if lr^.removable then begin
    for i := 0 to 5 do
      cdb.b[i] := chr(0);
    cdb.f.op := win_scsi_op_prevent_allow;
    cdb.g0.start := false;
    status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                   nil, 0, win_scsi_timeout);
  end;

  for i := 0 to 5 do
    cdb.b[i] := chr(0);
  cdb.f.op := win_scsi_op_release;
  cdb.f.lun := unit;
  status.all := win_scsi_command(u^.handle, lr, cdb, unit, scsi_$dir_out,
                                 u^.buf_ptr, 0, win_scsi_timeout);
  scsi_$release(u^.handle, status);
  u^.ready := false;
end;
