{ REM_NAME_$READ_DIR - read a directory's entries from a naming server.

  Image addresses:
    sau2  0x00E4A984  REM_NAME_$READ_DIR

  - The reply is received into a NETBUF header page, returned at the
    end.  Its variable-length entries are unpacked into the caller's
    48-byte records until max_entries are filled; names are padded with
    spaces to 32, and an unknown type ends the unpacking.

  Status stored:
    rem_name_$send_request's status: the entries were read, or the
      request failed
    status_$naming_last_entry_in_replicated_root_returned: the root's
      last entries were read
    status_$ok: that, but the reply holds more entries than were asked
      for
}

{ TODO(pascal) 32 frame bytes of REM_NAME_$READ_DIR hold nothing

  Of two 24-byte stretches of the SAU2 frame (after request, and between
  wire_type and the temporary holding its address) no instruction
  addresses any byte; the locals the image keeps in registers would take
  16 of them.  unused_24 (after request) and unused_8 (at the end) hold
  the other 32.  REM_NAME_$READ_REP's frame, the same request and page,
  has 16 open bytes in other places: not the same declarations.  Not
  settled. }

procedure rem_name_$read_dir(net: integer32;
                             node: integer32;
                             in dir_uid: uid_$t;
                             start_index: pinteger;
                             out entries: univ rem_name_$dir_entries_t;
                             max_entries: pinteger;
                             out count: pinteger;
                             out status: status_$t);
  options(val_param);
label
  done;
type
  data_ptr_t = ^os_$data_t;
var
  request: rem_name_$read_req_t;
  unused_24: array[1..24] of char;        { the TODO above }
  page_va: integer32;
  page_phys: integer32;
  reply_len: integer;
  wire_type: integer;
  reply: rem_name_$read_reply_ptr_t;      { through a data register }
  req: ^rem_name_$read_req_t;
  src: integer32;
  i: pinteger;                            { the loop count }
  j: pinteger;
  unused_8: array[1..8] of char;          { the TODO above }
begin
  netbuf_$get_hdr(page_phys, page_va);
  reply := rem_name_$read_reply_ptr_t(page_va);
  req := addr(request);

  count := 0;
  req^.opcode := 16#1000B;
  req^.dir_uid := dir_uid;
  req^.one := 1;
  req^.start_index := start_index;

  if not rem_name_$send_request(net, node, req^, 54, 0, 16#C, reply^,
                                rem_name_read_reply_size, reply_len,
                                status) then begin
    if status.all <> status_$naming_last_entry_in_replicated_root_returned
    then
      goto done;
    if max_entries < reply^.count then
      status.all := status_$ok;
  end;

  { the entries }
  src := integer32(addr(reply^.data));
  for i := 1 to reply^.count do begin
    if max_entries <= count then
      exit;
    count := count + 1;
    with entries[count] do begin
      os_$data_copy(data_ptr_t(src)^, wire_type, 2);
      src := src + 2;
      os_$data_copy(data_ptr_t(src)^, name_len, 2);
      src := src + 2;
      os_$data_copy(data_ptr_t(src)^, name, name_len);
      for j := name_len + 1 to 32 do
        name[j] := ' ';

      case wire_type of
        entry_type_normal: begin
            entry_type := entry_type_normal;
            src := src + name_len;
            os_$data_copy(data_ptr_t(src)^, uid, 8);
            src := src + 8;
            os_$data_copy(data_ptr_t(src)^, extra, 4);
            src := src + 4;
          end;
        entry_type_link: begin
            entry_type := entry_type_link_alt;
            src := name_len + src;
          end;
        otherwise begin
            count := count - 1;
            exit;
          end;
      end;
    end;
  end;

done:
  netbuf_$rtn_hdr(page_va);
end;
