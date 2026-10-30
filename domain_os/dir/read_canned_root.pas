{ dir_$read_canned_root - read the canned replicated root's entries from
  its name server (nested in dir_$dir_readu_fallback, itself nested in
  DIR_$DIR_READU).

  Image addresses:
    sau2  0x00E4DFFE  dir_$read_canned_root (nested)

  - Batches of at most 8 entries, and no more than the buffer's rest
    holds at 54 bytes an entry, are asked of REM_NAME_$DIR_READU and
    written in DIR_READU's current format, names in lower case.
  - Nested two levels deep; it reads both parents' parameters.

  Status stored:
    status_$ok: the entries were read
    rem_name_$dir_readu's status: a batch failed
}

  procedure dir_$read_canned_root;
  var
    entries: array[1..8] of rem_name_$dir_entry_t;
    remaining: linteger;
    got: pinteger;
    req_count: pinteger;
    out_ptr: dir_$readu_entry_ptr_t;
    batch: pinteger;
    i: integer;
    j: integer;
    c: char;
  begin
    status_ret.all := status_$ok;
    out_ptr := addr(buf);
    remaining := buf_size;

    repeat
      if max_entries - count_ret > 8 then
        batch := 8
      else
        batch := max_entries - count_ret;
      if batch > remaining div 16#36 then
        batch := remaining div 16#36;
      if batch = 0 then
        return;

      req_count := batch;
      rem_name_$dir_readu(dir_uid, entries, continuation, req_count, got,
                          status_ret);
      if status_ret.all <> status_$ok then
        return;

      for i := 1 to got do begin
        out_ptr^.enttype := entries[i].entry_type;
        out_ptr^.entuid := entries[i].uid;
        out_ptr^.entextra := entries[i].extra;
        out_ptr^.entlen := entries[i].name_len;

        for j := 1 to out_ptr^.entlen do begin
          c := entries[i].name[j];
          if c in ['A'..'Z'] then
            c := chr(ord(c) + 16#20);
          out_ptr^.entname[j] := c;
        end;

        out_ptr^.entnxt := (out_ptr^.entlen + 16#1A - 1) & (-4);
        out_ptr^.enthandle := i + count_ret;
        remaining := remaining - out_ptr^.entnxt;
        out_ptr := dir_$readu_entry_ptr_t(integer32(out_ptr) +
                                          out_ptr^.entnxt);
      end;

      count_ret := got + count_ret;
    until (continuation.all = 0) or else (got = 0);
  end;
