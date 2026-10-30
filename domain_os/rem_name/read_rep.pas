{ REM_NAME_$READ_REP - read a directory's replica records from a naming
  server.

  Image addresses:
    sau2  0x00E4AB44  REM_NAME_$READ_REP

  - The reply is received into a NETBUF header page, returned at the
    end; its 18-byte replica records are copied until max_entries are
    filled.
  - The SAU2 frame has 16 bytes more than its locals need: the stand-in
    unused_16 holds them (the TODO in rem_name/read_dir.pas).

  Status stored:
    rem_name_$send_request's status: the records were read, the root's
      last were, or the request failed
}

procedure rem_name_$read_rep(net: integer32;
                             node: integer32;
                             in dir_uid: uid_$t;
                             start_index: pinteger;
                             out reps: univ rem_name_$rep_entries_t;
                             max_entries: pinteger;
                             out count: pinteger;
                             out status: status_$t);
  options(val_param);
label
  done;
var
  request: rem_name_$read_req_t;
  page_va: integer32;
  page_phys: integer32;
  reply_len: integer;
  reply: rem_name_$read_reply_ptr_t;      { through a data register }
  req: ^rem_name_$read_req_t;
  i: pinteger;                            { the loop count }
  unused_16: array[1..16] of char;        { see the TODO(pascal) in
                                            rem_name/read_dir.pas }
begin
  netbuf_$get_hdr(page_phys, page_va);
  reply := rem_name_$read_reply_ptr_t(page_va);
  req := addr(request);

  count := 0;
  req^.opcode := 16#1000D;
  req^.dir_uid := dir_uid;
  req^.one := 1;
  req^.start_index := start_index;

  if not rem_name_$send_request(net, node, req^, 54, 0, 16#E, reply^,
                                rem_name_read_reply_size, reply_len,
                                status) then
    if status.all <> status_$naming_last_entry_in_replicated_root_returned
    then
      goto done;

  { the records }
  for i := 1 to reply^.count do begin
    if max_entries <= count then
      exit;
    count := count + 1;
    reps[count] := reply^.reps[i];
  end;

done:
  netbuf_$rtn_hdr(page_va);
end;
