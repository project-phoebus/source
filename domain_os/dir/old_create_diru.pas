{ DIR_$OLD_CREATE_DIRU - create a subdirectory in an old-format directory.

  Image addresses:
    sau2  0x00E571AE  DIR_$OLD_CREATE_DIRU

  - Under the parent's add lock (mode 4, rights 2) the process's entries
    of the four lock tables are saved and put back, as
    dir_$old_create_obj locks the new directory through them.
  - A failed entry backs the new object out (both default ACLs UID_$NIL,
    its pages truncated, new_dir_uid UID_$NIL).
  - Super-user mode, which name_$lock_dir entered, is left (not after
    the bad-leaf refusal).

  Status stored:
    dir_$old_add_entry's status: the object was created
    dir_$old_create_obj's status: it could not be
    name_$unlock_dir's status: the unlock failed
    name_$lock_dir's status: the parent could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure dir_$old_create_diru(in dir_uid: uid_$t;
                               in name: univ name_$long_name_t;
                               in name_len: pinteger;
                               var new_dir_uid: uid_$t;
                               out status_ret: status_$t);
var
  saved_uid: uid_$t;
  parsed: array[1..32] of char;
  entry: dir_$old_slot_ptr_t;
  local_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  parsed_len: pinteger;
  trunc_result: boolean;
  saved_handle: integer32;
  saved_mode: integer;
  saved_slot: integer32;
begin
  if not name_$validate_leaf(name, name_len, parsed, parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 4, 2, status_ret);
  if status_ret.all = status_$ok then begin
    { the process's lock state }
    saved_uid := name_$lock_uid[proc1_$current];
    saved_handle := name_$lock_handle[proc1_$current];
    saved_mode := name_$lock_mode[proc1_$current];
    saved_slot := name_$lock_slot[proc1_$current];

    dir_$old_create_obj(dir_uid, handle, 1, new_dir_uid, status_ret);
    if status_ret.all = status_$ok then begin
      dir_$old_add_entry(dir_uid, handle, parsed, parsed_len, 1,
                         new_dir_uid, false, entry, status_ret);
      if status_ret.all <> status_$ok then begin
        { back the new object out }
        dir_$old_set_default_acl(new_dir_uid, acl_$file_acl, uid_$nil,
                                 local_status);
        dir_$old_set_default_acl(new_dir_uid, acl_$dir_acl, uid_$nil,
                                 local_status);
        ast_$truncate(new_dir_uid, 0, 3, trunc_result, local_status);
        new_dir_uid := uid_$nil;
      end;
    end;

    name_$lock_uid[proc1_$current] := saved_uid;
    name_$lock_handle[proc1_$current] := saved_handle;
    name_$lock_mode[proc1_$current] := saved_mode;
    name_$lock_slot[proc1_$current] := saved_slot;

    name_$unlock_dir(local_status);
    if local_status.all <> status_$ok then
      status_ret := local_status;
  end;

  acl_$exit_super;
end;
