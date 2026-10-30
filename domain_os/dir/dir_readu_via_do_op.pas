{ dir_$dir_readu_via_do_op - read a directory's entries through
  DIR_$DO_OP (nested in DIR_$DIR_READU).

  Image addresses:
    sau2  0x00E4E1FE  dir_$dir_readu_via_do_op (nested)

  - Operation-16#42 requests, each continuing after the last batch's
    last entry.  They stop when a batch returns nothing, the directory
    ends, the count is reached, or less than 1024 bytes were asked.
  - A returned name over 255 or a batch larger than the space left
    crashes the system.
  - Nested in DIR_$DIR_READU, whose parameters it reads.

  Status stored:
    the last reply's status: a name was given
    name_$bad_leaf: a name longer than 255
}

  procedure dir_$dir_readu_via_do_op(out status_ret: status_$t);
  var
    response: dir_$readu_reply_t;
    request: dir_$readu_req_t;
    received_len: integer;
    i: integer;
    buf_va: integer32;
    remaining: integer32;
    full: boolean;
    last: dir_$readu_entry_ptr_t;
  begin
    request.hdr.op := dir_op_dir_readu;
    request.hdr.uid := dir_uid;
    request.hdr.version := dir_$op_tab[33].version;

    count_ret := 0;
    if name_len > 255 then begin
      status_ret.all := name_$bad_leaf;
      return;
    end;

    request.body.name_len := name_len;
    for i := 1 to name_len do
      request.body.name[i] := name[i];

    status_ret.all := status_$ok;
    buf_va := integer32(addr(buf));
    remaining := buf_size;

    repeat
      request.body.max_size := remaining;
      request.body.continuation := continuation.all;
      request.body.max_entries := max_entries - count_ret;
      request.body.buf_va := univ_ptr(buf_va);

      dir_$do_op(request, dir_$op_tab[33].base_size + request.body.name_len,
                 16#24, response, received_len);

      status_ret := response.hdr.status;
      if status_ret.all <> status_$ok then
        return;
      continuation.all := response.continuation;
      if response.count = 0 then
        exit;

      count_ret := count_ret + response.count;
      last := dir_$readu_entry_ptr_t(buf_va + response.last_offset);

      request.body.name_len := last^.entlen;
      if request.body.name_len > 255 then
        crash_system(status_$naming_internal_error);
      for i := 1 to request.body.name_len do
        request.body.name[i] := last^.entname[i];

      remaining := remaining - response.size;
      if remaining < 0 then
        crash_system(status_$naming_internal_error);
      buf_va := buf_va + response.size;

      full := (remaining = 0) or (request.body.max_size < 1024);
    until (continuation.all = 0) or else (count_ret = max_entries) or else
          full;

    if status_ret.all <> status_$ok then
      return;

    if continuation.all = 0 then
      name_len := 0
    else if count_ret <> 0 then begin
      name_len := last^.entlen;
      for i := 1 to name_len do
        name[i] := last^.entname[i];
    end;
  end;
