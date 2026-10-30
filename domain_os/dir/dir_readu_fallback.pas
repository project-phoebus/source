{ dir_$dir_readu_fallback - read a directory the old way, or the canned
  root's entries from its name server (nested in DIR_$DIR_READU).

  Image addresses:
    sau2  0x00E4E1A8  dir_$dir_readu_fallback (nested)

  - Nested in DIR_$DIR_READU, whose parameters it reads; its own nested
    dir_$read_canned_root (dir/read_canned_root.pas) is in its
    declaration part.

  Status stored:
    dir_$read_canned_root's status: the canned replicated root
    dir_$old_dir_readu's status: any other directory
}

  procedure dir_$dir_readu_fallback(out status_ret: status_$t);

%include 'dir/read_canned_root.pas';         { dir_$read_canned_root }

  begin
    count_ret := 0;

    if dir_uid = name_$canned_rep_root_uid then
      dir_$read_canned_root
    else
      dir_$old_dir_readu(dir_uid, continuation, max_entries, buf_size, buf,
                         count_ret, status_ret);
  end;
