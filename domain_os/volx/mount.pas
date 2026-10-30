{ VOLX_$MOUNT - mount a logical volume.

  Image addresses:
    sau2  0x00E6B118  VOLX_$MOUNT

  - An already mounted physical volume is accepted, and is left mounted
    on a failure.
  - A failure undoes the steps already done, in reverse order.
  - The location goes into the VTOC's mount word unmasked;
    VTOC_$DISMOUNT's status is ignored.

  Status stored:
    status_$ok: the volume was mounted
    status_$volume_disk_is_write_protected: the volume was mounted, but
      the disk is write protected and write_prot is not set (a warning)
    disk_$pv_mount's status: the physical volume could not be mounted
    disk_$lv_uid's or disk_$lv_mount's status: the logical volume could
      not be found or mounted
    vtoc_$mount's status: the VTOC could not be mounted
    vtoc_$get_name_dirs's status: the volume's directories were not
      found
    status_$volx_volume_table_full: the parent directory is full
    status_$volx_directory_in_use: the mount point already exists
    dir_$add_mount's status: the mount point could not be added
}

{ TODO(pascal) the frame is not reproduced

  The SAU2 image's frame places the value parameters' copies among the
  locals, where dpc puts them first, from the top, and leaves gaps no
  declared local explains. }

procedure volx_$mount(in dev: integer; in bus: integer; in ctlr: integer;
                      in lv_num: integer; salvage_ok: boolean;
                      in write_prot: boolean; parent_uid: uid_$t;
                      out dir_uid_ret: uid_$t; out status: status_$t);
label
  dismount_vtoc, dismount_lv, dismount_pv, report;
var
  dir_uid: uid_$t;
  name_dir_uid: uid_$t;
  lv_uid: uid_$t;
  vtoc_status: status_$t;
  dismount_status: status_$t;
  local_status: status_$t;
  loc: vtoc_$mount_loc_t;
  vol_idx: integer;
  pv_idx: integer;
  already_mounted: boolean;
begin
  pv_idx := disk_$pv_mount(dev, bus, ctlr, local_status);

  already_mounted := local_status.all = status_$disk_already_mounted;
  if not already_mounted and then (local_status.all <> status_$ok) then begin
    status := local_status;
    return;
  end;

  disk_$lv_uid(pv_idx, lv_num, lv_uid, local_status);
  if local_status.all <> status_$ok then
    goto dismount_pv;

  vol_idx := disk_$lv_mount(lv_uid, local_status);
  if local_status.all <> status_$ok then
    goto dismount_pv;

  loc.dev := dev;
  loc.bus := bus;
  loc.ctlr := ctlr;
  loc.lv_num := lv_num;

  vtoc_$mount(vol_idx, loc, salvage_ok, write_prot, vtoc_status);
  if vtoc_status.all <> status_$ok then begin
    if vtoc_status.all <> status_$disk_write_protected then
      goto dismount_lv;
    if write_prot then
      vtoc_status.all := status_$ok
    else
      vtoc_status.all := status_$volume_disk_is_write_protected;
  end;

  vtoc_$get_name_dirs(vol_idx, name_dir_uid, dir_uid, local_status);
  if local_status.all <> status_$ok then
    goto dismount_vtoc;

  dir_uid_ret := dir_uid;

  if parent_uid <> uid_$nil then begin
    dir_$add_mount(parent_uid, dir_uid, local_status);
    if local_status.all = name_$directory_full then
      local_status.all := status_$volx_volume_table_full
    else if local_status.all = name_$already_exists then
      local_status.all := status_$volx_directory_in_use;
  end;
  if local_status.all <> status_$ok then
    goto dismount_vtoc;

  with volx_$table[vol_idx] do begin
    e_dir_uid := dir_uid;
    e_lv_uid := lv_uid;
    e_parent_uid := parent_uid;
    e_dev := dev;
    e_bus := bus;
    e_ctlr := ctlr;
    e_lv_num := lv_num;
  end;
  goto report;

dismount_vtoc:
  vtoc_$dismount(vol_idx, false, dismount_status);
  goto dismount_pv;

dismount_lv:
  disk_$dismount(vol_idx);

dismount_pv:
  if not already_mounted then
    disk_$dismount(pv_idx);

report:
  if local_status.all = status_$ok then
    status := vtoc_status
  else
    status := local_status;
end;
