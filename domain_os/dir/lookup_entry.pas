{ dir_$lookup_entry - look a name up in a directory, without the cache.

  Image addresses:
    sau2  0x00E4CB6A  dir_$lookup_entry (nested)

  - As super-user, the directory opened for reading; a file's UID is
    marked cacheable unless it is a mount point (then the mounted UID).
    Another entry type crashes the system.
  - A name missing from the root is asked of the network and added to
    the local root (its capitals folded to lower case).
  - Nested in dir_$do_op_get_entryu, whose parameters it reads.

  Status stored:
    status_$ok: the name was found, here or by the network
    name_$not_found: not found, or the network failed
    dir_$open_dir's status: the directory could not be opened
}

  procedure dir_$lookup_entry(out found_ret: boolean;
                              out status_ret: status_$t);
  label
    20;
  var
    rep: rem_name_$dir_entry_t;
    add_status: status_$t;
    entry: dir_$entry_ptr_t;
    handle: dir_$handle_ptr_t;
    volume: integer;
    find_extra: integer;
    depth: integer;
    n: integer;
    j: integer;
  begin
    found_ret := false;
    acl_$enter_super;
    dir_$open_dir(uid.uid, 1, 1, handle, status_ret);
    if status_ret.all <> status_$ok then
      goto 20;

    if dir_$find_entry(handle^, name, name_len, 0, entry, find_extra,
                       depth) then begin
      extra_ret := 0;
      case entry^.flags & 7 of
        dir_entry_file: begin
          { a file }
          type_ret := 1;
          uid_ret.uid := entry^.uid;
          found_ret := true;
          { a mount point's UID }
          for n := 1 to dir_$mttab.count do
            if uid_ret.uid = dir_$mttab.mount_uid[n] then begin
              found_ret := false;
              uid_ret.uid := dir_$mttab.mount_tgt[n];
              exit;
            end;
        end;
        dir_entry_hard_link: begin
          { a hard link }
          type_ret := 1;
          uid_ret.uid := entry^.uid;
          extra_ret := entry^.extra;
        end;
        dir_entry_soft_link: begin
          { a soft link }
          type_ret := 3;
        end;
        otherwise begin
          crash_system(status_$naming_internal_error);
        end;
      end;
    end
    else if uid.uid = name_$root_uid then begin
      { ask the network }
      dir_$release_handle(handle);
      rem_name_$get_entry(uid.uid, name, name_len, rep, status_ret);
      if (status_ret.all = status_$ok) and then (rep.entry_type = 1) then
      begin
        { the name's capitals folded }
        for j := 1 to rep.name_len do
          if rep.name[j] in ['A'..'Z'] then
            rep.name[j] := chr(ord(rep.name[j]) + 16#20);

        { added to the local root }
        dir_$do_op_add_entry(uid.uid, 0, rep.name, rep.name_len, 3,
                             rep.extra, rep.uid, 0, '', volume,
                             add_status);

        type_ret := rep.entry_type;
        uid_ret.uid := rep.uid;
        extra_ret := rep.extra;
      end
      else
        status_ret.all := name_$not_found;
    end
    else
      status_ret.all := name_$not_found;

    dir_$release_handle(handle);

  20:
    acl_$exit_super;
  end;
