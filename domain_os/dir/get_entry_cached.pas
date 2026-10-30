{ dir_$get_entry_cached - look a name up through the per-UID entry cache.

  Image addresses:
    sau2  0x00E4CD90  dir_$get_entry_cached (nested)

  - The slot is the UID's second word plus the name's characters, mod
    111; a hit needs the same name, directory and time stamp.  Names
    longer than 17 are looked up directly.
  - The cache is read and filled under DIR_$MUTEX.
  - Nested in dir_$do_op_get_entryu, whose parameters it reads.

  Status stored:
    status_$ok: a hit, its rights read already or checked now
    name_convert_acl_status' status: a hit's rights check failed (the
      UID's high half cleared)
    dir_$lookup_entry's status: a miss, or a long name
    status_$naming_directory_object_not_found: AST_$GET_DTV found no
      object
    ast_$get_dtv's status: another AST_$GET_DTV failure
}

  procedure dir_$get_entry_cached(out status_ret: status_$t);
  label
    10;
  var
    found: boolean;
    cur_dtv: time_$clock_t;
    location: integer32;
    hash: pinteger;
    slot: pinteger;
    i: pinteger;
    match: boolean;
    rights: acl_$rights_word_t;
  begin
    { a long name: no cache }
    if name_len > 17 then begin
      dir_$entry_cache_too_long_name := dir_$entry_cache_too_long_name + 1;
      dir_$lookup_entry(found, status_ret);
      return;
    end;

    { the directory's time stamp }
    dir_$entry_cache_tries := dir_$entry_cache_tries + 1;
    location := 0;
    ast_$get_dtv(uid.uid, location, cur_dtv, status_ret);
    if status_ret.all = file_$object_not_found then
      status_ret.all := status_$naming_directory_object_not_found;
    if status_ret.all <> status_$ok then
      return;

    { the slot }
    hash := uid.w1;
    for i := 1 to name_len do
      hash := hash + ord(name[i]);
    slot := hash mod 111;

    ml_$exclusion_start(dir_$mutex);

    with dir_$entry_cache[slot] do begin
      { a hit? }
      if (lf.len = name_len) and then (dir_uid = uid.uid) then begin
        match := true;
        for i := 1 to name_len do
          if entry_name[i] <> name[i] then begin
            match := false;
            exit;
          end;
        if match and then (cur_dtv = dtv) then begin
          { the hit }
          type_ret := 1;
          uid_ret.uid := entry_uid;
          extra_ret := 0;
          dir_$entry_cache_hits := dir_$entry_cache_hits + 1;

          { the rights already read }
          if (w & 16#100) <> 0 then begin
            dir_$entry_cache_skipped_acl :=
              dir_$entry_cache_skipped_acl + 1;
            goto 10;
          end;

          { else checked now }
          ml_$exclusion_stop(dir_$mutex);
          discard(acl_$rights(uid.uid, false, 1, 1, status_ret));
          if status_ret.all = status_$ok then
            return;
          name_convert_acl_status(status_ret);
          uid_ret.uid.high := 0;
          return;
        end;
      end;

      { a miss }
      ml_$exclusion_stop(dir_$mutex);
      dir_$lookup_entry(found, status_ret);
      if status_ret.all <> status_$ok then
        return;
      if not found then
        return;

      rights := acl_$min_rights(uid.uid);
      ml_$exclusion_start(dir_$mutex);

      { the slot filled }
      dir_uid := uid.uid;
      entry_uid := uid_ret.uid;
      dtv := cur_dtv;
      lf.len := name_len;
      lf.acl_ok := 0 in rights;
      for i := 1 to name_len do
        entry_name[i] := name[i];
    end;

  10:
    ml_$exclusion_stop(dir_$mutex);
  end;
