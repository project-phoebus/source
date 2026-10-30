{ name_$lock_dir - lock and map an old-format directory for the current
  process.

  Image addresses:
    sau2  0x00E54854  name_$lock_dir

  - FILE_$PRIV_LOCK in the mode, retried every 16384 ticks while in use,
    at most 120 times and 120 high clock units, never for a server
    process; super-user mode is entered on every path.
  - The rights are checked, then a cached mapping (node, /com, the
    working or naming directory) used or one made with MST_$MAPS.  A
    failure after the lock releases it.

  Status stored:
    file_$priv_lock's status: the directory was locked and mapped
    status_$naming_directory_locked: the lock was busy too long
    file_$priv_lock's status, fail bit set: another lock failure
    name_convert_acl_status' status: the rights were refused
    mst_$maps' status, fail bit set: the mapping failed
    status_$naming_bad_directory: page 0's version is not 1
}

procedure name_$lock_dir(dir_uid: uid_$t;
                         out handle_ret: dir_$old_dir_ptr_t;
                         mode: integer; rights: pinteger;
                         out status_ret: status_$t);
  internal;
label
  10;
var
  delay: time_$clock_t;
  local_status: status_$t;
  map_info: integer32;
  lock_rights: integer;
  retries: integer;
  start: time_$clockh_t;
begin
  retries := 0;
  start := time_$clockh;

  repeat
    { one attempt }
    name_$lock_mode[proc1_$current] := mode;
    name_$lock_handle[proc1_$current] := 0;
    file_$priv_lock(dir_uid, proc1_$as_id, 0, mode, false, 16#88, 0, 0, 0,
                    0, 0, 1, name_$lock_slot[proc1_$current], lock_rights,
                    status_ret);

    if status_ret.all = status_$ok then begin
      name_$lock_uid[proc1_$current] := dir_uid;
      exit;
    end;

    { busy: wait, or give up }
    if status_ret.all <> file_$object_in_use then
      exit;
    if proc1_$type[proc1_$current] = 9 then begin
      status_ret.all := status_$naming_directory_locked;
      exit;
    end;
    retries := retries + 1;
    if (retries > 120) or else (time_$clockh - start > 120) then begin
      status_ret.all := status_$naming_directory_locked;
      exit;
    end;

    delay.high := 0;
    delay.low := 16#4000;
    time_$wait(time_$relative, delay, local_status);
  until false;

  if status_ret.all <> status_$ok then begin
    if status_ret.all <> status_$naming_directory_locked then
      status_ret.fail := true;
    acl_$enter_super;
    return;
  end;

  { the rights }
  if rights <> 0 then begin
    discard(acl_$rights(dir_uid, false, rights, 1, status_ret));
    acl_$enter_super;
    if status_ret.all <> status_$ok then begin
      name_convert_acl_status(status_ret);
      goto 10;
    end;
  end
  else
    acl_$enter_super;

  { the mapping }
  if (dir_uid = name_$node_uid) and then name_$node_mapped_info.active
     and then (name_$node_mapped_info.reserved_02 = 0)
     and then (name_$node_mapped_info.entry_count = 1) then
    handle_ret := dir_$old_dir_ptr_t(name_$node_mapped_info.first_base)
  else if (dir_uid = name_$com_uid) and then name_$com_mapped_info.active
          and then (name_$com_mapped_info.reserved_02 = 0)
          and then (name_$com_mapped_info.entry_count = 1) then
    handle_ret := dir_$old_dir_ptr_t(name_$com_mapped_info.first_base)
  else if (dir_uid = name_$wdir_uid[proc1_$as_id])
          and then name_$wdir_mapped_info[proc1_$as_id].active
          and then (name_$wdir_mapped_info[proc1_$as_id].reserved_02 = 0)
          and then (name_$wdir_mapped_info[proc1_$as_id].entry_count = 1)
          then
    handle_ret := dir_$old_dir_ptr_t(
                    name_$wdir_mapped_info[proc1_$as_id].first_base)
  else if (dir_uid = name_$ndir_uid[proc1_$as_id])
          and then name_$ndir_mapped_info[proc1_$as_id].active
          and then (name_$ndir_mapped_info[proc1_$as_id].reserved_02 = 0)
          and then (name_$ndir_mapped_info[proc1_$as_id].entry_count = 1)
          then
    handle_ret := dir_$old_dir_ptr_t(
                    name_$ndir_mapped_info[proc1_$as_id].first_base)
  else begin
    handle_ret := mst_$maps(proc1_$as_id, true, dir_uid, 0, 65536, 16#16,
                            0, true, map_info, status_ret);
    if status_ret.code <> 0 then begin
      status_ret.fail := true;
      goto 10;
    end;
  end;

  name_$lock_handle[proc1_$current] := integer32(handle_ret);
  if handle_ret^.hdr.version = 1 then
    return;
  status_ret.all := status_$naming_bad_directory;

10:
  name_$unlock_dir(local_status);
end;
