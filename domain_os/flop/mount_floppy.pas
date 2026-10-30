{ flop_$mount_floppy - mount the floppy's volume and link it as /flp.

  Image addresses:
    sau2  0x00E323E6  flop_$mount_floppy (nested)

  - Nested in FLOP_$BOOT (flop/boot.pas includes it).  Logical volume 1
    of the floppy is mounted, its root linked into the node's directory
    as `flp' and given its parent.
  - A failure after the mount dismounts the volume and drops the link.

  Status stored:
    the mount's status: the floppy was mounted (the write-protected
      warning cleared), or the mount failed
    status_$ok: /flp already names this volume, or DIR_$SET_DAD reports
      the disk write-protected
    dir_$addu's or dir_$set_dad's status (fail bit cleared): those failed
}

procedure flop_$mount_floppy(out status_ret: status_$t);
var
  node_uid: uid_$t;
  existing_uid: uid_$t;
  mount_uid: uid_$t;
  local_status: status_$t;
  mount_status: status_$t;
  added_dir: boolean;
begin
  { the mount }
  volx_$mount(1, 0, 0, 1, true, false, uid_$nil, mount_uid, mount_status);
  if mount_status.all <> status_$ok then begin
    mount_status.fail := false;
    if mount_status.all <> status_$volume_disk_is_write_protected then begin
      status_ret := mount_status;
      return;
    end;
  end;

  node_uid := name_$get_node_uid;

  { the link }
  dir_$addu(node_uid, 'flp', 3, mount_uid, status_ret);
  if status_ret.all = status_$ok then
    added_dir := true
  else if status_ret.all = name_$already_exists then begin
    added_dir := false;
    name_$resolve('/flp', 4, existing_uid, local_status);
    if (local_status.all = status_$ok) and then (mount_uid = existing_uid) then
      status_ret.all := status_$ok;
  end
  else
    added_dir := false;

  { the root's parent }
  if status_ret.all = status_$ok then begin
    dir_$set_dad(mount_uid, node_uid, status_ret);
    status_ret.fail := false;
    if status_ret.all = status_$disk_write_protected then
      status_ret.all := status_$ok;
  end;

  { undo on failure, else the mount's status }
  if status_ret.all <> status_$ok then begin
    volx_$dismount(1, 0, 0, 1, mount_uid, false, local_status);
    if added_dir then
      dir_$dropu(node_uid, 'flp', 3, mount_uid, local_status);
  end
  else
    status_ret := mount_status;
end;
