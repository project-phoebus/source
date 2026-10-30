{ NAME_$INIT - initialize the naming server.

  Image addresses:
    sau2  0x00E31624  NAME_$INIT
    sau9  0x3C437714  NAME_$INIT
    sau2  0x00E31578  name_$init_check_status (nested)

  - As super-user: the root and node directory UIDs from the arguments,
    or the boot volume's VTOC when the root's is UID_$NIL; every address
    space gets the node directory as its working and naming directory.
  - "/com" is mapped (else the node directory), and "/sys/node_data.<node
    id>" (or "/sys/node_data") resolved as the node-data directory.
  - A failed step is reported by name_$init_check_status, which crashes.

  Status stored: none.
}

{ TODO(pascal) NAME_$INIT's frame against its locals

  The objects the SAU2 code addresses are node_uid, root_uid, status and
  path_len; uids_supplied, len and i are held in registers (each keeps a
  slot).  The 8-byte objects' 8-alignment explains node_uid's and
  root_uid's places, but not the 4 bytes above status nor the 2 above
  path_len; with the three register-held locals the frame still has 4
  bytes at the bottom.  The locals are declared in an order that puts
  each addressed object at its offset, with stand-ins (unused_14,
  unused_1a, unused_28). }

[section(os_init_proc, os_init_data)]
procedure name_$init(in vol_root_uid: uid_$t; in vol_node_uid: uid_$t);
var
  node_uid: uid_$t;
  root_uid: uid_$t;
  unused_14: integer32;                   { the TODO above }
  status: status_$t;
  unused_1a: integer;                     { the TODO above }
  path_len: integer;
  uids_supplied: boolean;
  len: integer;
  i: integer;
  unused_28: integer32;                   { the TODO above }
  path_buf: static array[1..256] of char; { OS_INIT_DATA +0x000 }

  { name_$init_check_status - report a failed step of NAME_$INIT and
    crash.

    - When the status's code word is not 0: "Unable to <step>
      "<param1>" -- <status>", a wait of crash_delay, and a crash with
      the status.
    - Nested in NAME_$INIT, whose status it reads.

    Status stored: none. }

  procedure name_$init_check_status(in msg: univ vfmt_$string_t;
                                    in param1: univ vfmt_$generic_signed_arg;
                                    param2: integer32);
  var
    wait_status: status_$t;
    crash_delay: static time_$clock_t := [high := 16#28, low := 0];
                                          { OS_INIT_DATA +0x100 }
  begin
    if status.code <> 0 then begin
      vfmt_$write2('%/%/%/%/%/%/%/Unable to %$', 0, 0);
      vfmt_$write2(msg, 0, 0);
      vfmt_$write5(' "%a" -- %lh%.', param1, param2, status, 0, 0);
      time_$wait(time_$relative, crash_delay, wait_status);
      crash_system(status);
    end;
  end;

begin
  { the root and node directories }
  acl_$enter_super;
  dir_$init;
  uids_supplied := vol_root_uid <> uid_$nil;
  if not uids_supplied then begin
    vtoc_$get_name_dirs(cal_$boot_volx, root_uid, node_uid, status);
    name_$init_check_status('get root directory uids from vtoc%$', 0, 0);
  end
  else begin
    root_uid := vol_root_uid;
    node_uid := vol_node_uid;
  end;
  name_$root_uid := root_uid;
  name_$node_uid := node_uid;

  { every address space starts in the node directory }
  for i := 0 to name_$max_asids - 1 do begin
    name_$wdir_uid[i] := name_$node_uid;
    name_$ndir_uid[i] := name_$node_uid;
    name_$wdir_mapped_info[i].active := false;
    name_$ndir_mapped_info[i].active := false;
  end;
  name_$node_mapped_info.active := false;
  name_$com_mapped_info.active := false;

  discard(name_$map_dir(name_$node_uid, 0, name_$node_mapped_info, status));
  name_$init_check_status('map //%$', 0, 0);

  { /com, or the node directory }
  path_buf := '/com';
  path_len := 4;
  name_$resolve(path_buf, path_len, name_$com_uid, status);
  if (status.all <> status_$ok) or else
     not name_$map_dir(name_$com_uid, 0, name_$com_mapped_info, status)
  then begin
    name_$com_uid := name_$node_uid;
    name_$com_mapped_info := name_$node_mapped_info;
  end;

  if not uids_supplied then begin
    file_$set_dirptr(name_$node_uid, name_$canned_root_uid, status);
    name_$init_check_status('set // as father of /%$', 0, 0);
    if status.all <> status_$ok then
      crash_system(status);
  end;

  { "/sys/node_data.<id>" }
  vfmt_$encode2('/sys/node_data.%lh%$', path_buf, 256, path_len, node_$me,
                0);
  len := path_len;
  if not uids_supplied then
    len := 14
  else
    for i := 16 to len do
      if path_buf[i] in ['A'..'Z'] then
        path_buf[i] := chr(ord(path_buf[i]) + 32);
  path_len := len;

  name_$resolve(path_buf, path_len, name_$node_data_uid, status);
  name_$init_check_status('resolve%$', path_buf, len);

  acl_$exit_super;
end;
