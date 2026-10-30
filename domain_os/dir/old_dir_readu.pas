{ DIR_$OLD_DIR_READU - read an old-format directory's entries.

  Image addresses:
    sau2  0x00E57C80  DIR_$OLD_DIR_READU

  - The canned replicated root is never an old-format directory: asked
    for it, the system crashes.

  Status stored:
    dir_$old_read_entries' status: always
}

procedure dir_$old_dir_readu(in dir_uid: uid_$t;
                             var continuation: univ dir_$readu_cont_t;
                             in max_entries: integer32;
                             in buf_size: integer32;
                             out buf: univ dir_$readu_buf_t;
                             out count_ret: linteger;
                             out status_ret: status_$t);
begin
  if dir_uid = name_$canned_rep_root_uid then
    crash_system(status_$naming_internal_error);

  dir_$old_read_entries(dir_uid, continuation, max_entries, buf_size, buf,
                        count_ret, status_ret);
end;
