{ DIR_$DIR_READU - read a directory's entries into the caller's buffer.

  Image addresses:
    sau2  0x00E4E3A6  DIR_$DIR_READU

  - The canned replicated root is read through dir_$dir_readu_fallback
    (its name server); any other directory through
    dir_$dir_readu_via_do_op, then the fallback for the old format.
  - The nested routines are included in its declaration part.

  Status stored:
    the nested routine's status: some entries were read, or the read
      failed
    status_$naming_bad_buffer_size: a buffer of no bytes, or no entry
      fitted short of the directory's end
}

procedure dir_$dir_readu(in dir_uid: uid_$t;
                         in out name: univ name_$long_name_t;
                         in out name_len: pinteger;
                         in out continuation: rem_name_$continuation_t;
                         in max_entries: integer32;
                         in buf_size: integer32;
                         var buf: univ dir_$readu_buf_t;
                         out count_ret: linteger;
                         out status_ret: status_$t);

%include 'dir/dir_readu_fallback.pas';       { dir_$dir_readu_fallback
                                               (dir_$read_canned_root
                                               nested in it) }
%include 'dir/dir_readu_via_do_op.pas';      { dir_$dir_readu_via_do_op }

begin
  if buf_size <= 0 then
    status_ret.all := status_$naming_bad_buffer_size
  else begin
    if dir_uid = name_$canned_rep_root_uid then
      dir_$dir_readu_fallback(status_ret)
    else begin
      dir_$dir_readu_via_do_op(status_ret);
      if (status_ret.all = file_$bad_reply_received_from_remote_node) or else
         (status_ret.all = status_$naming_bad_directory) then
        dir_$dir_readu_fallback(status_ret);
    end;

    if (status_ret.all = status_$ok) and then (count_ret = 0) and then
       (continuation.all <> 0) then
      status_ret.all := status_$naming_bad_buffer_size;
  end;
end;
