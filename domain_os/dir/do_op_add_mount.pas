{ dir_$do_op_add_mount - DIR_$DO_OP's handler for operation 16#5A,
  entering a mount in the mount table.

  Image addresses:
    sau2  0x00E5325E  dir_$do_op_add_mount

  - As super-user, the mount point's directory opened for writing (mode
    2, rights 8).
  - Under DIR_$MUTEX the entry is appended, and every entry-cache slot
    for the mount point loses its directory UID (UID_$NIL).

  Status stored:
    ast_$get_common_attributes' status: the mount was entered
    dir_$open_dir's status: the directory could not be opened, or
      (status_$ok) the table holds the mount already
    status_$naming_directory_locked: the mount point is of sub-type 2
    name_$directory_full: the table would reach 8 entries
}

procedure dir_$do_op_add_mount(in dir_uid: uid_$t; in mount_uid: uid_$t;
                               node_id: integer32;
                               out status_ret: status_$t);
label
  10;
var
  attrs: ast_$common_attr_t;
  loc: file_$obj_loc_t;
  handle: dir_$handle_ptr_t;
  count: integer32;
  n: integer;
  i: integer;
begin
  acl_$enter_super;
  dir_$open_dir(dir_uid, 2, 8, handle, status_ret);
  acl_$exit_super;
  if status_ret.all <> status_$ok then
    goto 10;

  { already mounted }
  for n := 1 to dir_$mttab.count do
    if (node_id = dir_$mttab.mount_node[n]) and then
       (dir_$mttab.mount_uid[n] = dir_uid) and then
       (dir_$mttab.mount_tgt[n] = mount_uid) then
      goto 10;

  loc.uid := dir_uid;
  loc.flags := loc.flags - [6];
  ast_$get_common_attributes(loc, 16#80, attrs, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  if ord(attrs.sub_type) = 2 then begin
    status_ret.all := status_$naming_directory_locked;
    goto 10;
  end;

  ml_$exclusion_start(dir_$mutex);
  count := dir_$mttab.count + 1;
  if count >= 8 then begin
    ml_$exclusion_stop(dir_$mutex);
    status_ret.all := name_$directory_full;
    goto 10;
  end;

  dir_$mttab.count := count;
  dir_$mttab.mount_uid[count] := dir_uid;
  dir_$mttab.mount_tgt[dir_$mttab.count] := mount_uid;
  dir_$mttab.mount_node[dir_$mttab.count] := node_id;

  { the cached entries under the mount point }
  for i := 0 to 110 do
    if dir_$entry_cache[i].entry_uid = dir_uid then
      dir_$entry_cache[i].dir_uid := uid_$nil;

  ml_$exclusion_stop(dir_$mutex);

10:
  dir_$release_handle(handle);
end;
