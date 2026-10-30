{ VOLX_$DISMOUNT - dismount a logical volume.

  Image addresses:
    sau2  0x00E6B346  VOLX_$DISMOUNT

  - A physical volume that mounts afresh was not mounted: it is
    dismounted again.
  - When the storage module was stopped, a volume whose UID is still the
    table's is revalidated; another is refused unless force is set.

  Status stored:
    status_$ok: the volume was dismounted
    status_$volume_logical_vol_not_mounted: the node is really diskless,
      no mounted volume is at the location, or its physical volume was
      not mounted
    disk_$pv_mount's status: the physical volume could not be mounted
    status_$volume_physical_vol_replaced_since_mount: the storage module
      was stopped, the volume's UID is not the table's and force is not
      set
    status_$volume_unable_to_dismount_boot_volume: the volume is the
      boot volume
    status_$volume_entry_directory_not_on_logical_volume: entry_uid is
      not nil and not the volume's directory
    dir_$drop_mount's status: the mount point could not be dropped
    ast_$dismount's status: the volume's AST state was not dismounted
}

{ TODO(pascal) the frame is not reproduced

  The SAU2 image's frame lays the value parameters' copies out below
  the locals, upward in parameter order, and leaves bytes no declared
  local explains; dpc puts the copies first, from the top, in parameter
  order. }

procedure volx_$dismount(dev: integer; bus: integer; ctlr: integer;
                         lv_num: integer; entry_uid: uid_$t;
                         in force: boolean; out status: status_$t);
label
  out_;
var
  lv_uid: uid_$t;
  local_status: status_$t;
  pv_idx: integer;
  vol_idx: integer;
begin
  if network_$really_diskless then begin
    local_status.all := status_$volume_logical_vol_not_mounted;
    goto out_;
  end;
  vol_idx := find_volx(dev, bus, ctlr, lv_num);
  if vol_idx = 0 then begin
    local_status.all := status_$volume_logical_vol_not_mounted;
    goto out_;
  end;

  pv_idx := disk_$pv_mount(dev, bus, ctlr, local_status);
  if local_status.all = status_$ok then begin
    disk_$dismount(pv_idx);
    local_status.all := status_$volume_logical_vol_not_mounted;
    goto out_;
  end;
  if local_status.all <> status_$disk_already_mounted then
    goto out_;

  disk_$lv_uid(pv_idx, lv_num, lv_uid, local_status);
  if local_status.all = status_$storage_module_stopped then begin
    if lv_uid <> volx_$table[vol_idx].e_lv_uid then begin
      if not force then begin
        local_status.all := status_$volume_physical_vol_replaced_since_mount;
        goto out_;
      end;
    end
    else
      disk_$revalidate(vol_idx);
  end;

  if vol_idx = cal_$boot_volx then begin
    local_status.all := status_$volume_unable_to_dismount_boot_volume;
    goto out_;
  end;

  if (entry_uid <> uid_$nil)
     and then (entry_uid <> volx_$table[vol_idx].e_dir_uid) then begin
    local_status.all := status_$volume_entry_directory_not_on_logical_volume;
    goto out_;
  end;

  if volx_$table[vol_idx].e_parent_uid <> uid_$nil then begin
    dir_$drop_mount(volx_$table[vol_idx].e_parent_uid, entry_uid, 0,
                    local_status);
    if local_status.all <> status_$ok then
      goto out_;
    volx_$table[vol_idx].e_parent_uid := uid_$nil;
  end;

  ast_$dismount(vol_idx, force, local_status);
  if local_status.all = status_$ok then
    volx_$table[vol_idx].e_lv_num := 0;

out_:
  status := local_status;
end;
