{ REM_FILE_$GET_SEG_MAP - read an object's segment map from its home node.

  Image addresses:
    sau2  0x00E61F3E  REM_FILE_$GET_SEG_MAP

  - A 40-byte reply hands back its map; a 12-byte one is one segment's
    bits, or-ed in, and the next segment is asked for until its offset
    passes end_offset.
  - A reply of another length sends the same request again; of a 40-byte
    reply's map only the first longword is handed back.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$get_seg_map(var addr_info: integer32;
                                in file_uid: uid_$t;
                                start_offset: linteger;
                                end_offset: linteger; type_flag: boolean;
                                out seg_map_out: ast_$seg_map_t;
                                out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  seg_offset: integer;
  start_seg: pinteger;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
  i: integer;
  j: integer32;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_get_seg_map;
  request.uid := file_uid;

  request.seg_index := start_offset div 16#8000;
  start_seg := request.seg_index;
  request.seg_version := rem_file_req_version;
  request.seg_force := true;
  request.seg_type := type_flag;
  request.seg_offset := start_offset div 16#400;
  request.seg_magic := 16#10020;

  repeat
    nil_word := 0;
    rem_file_$send_request(addr_info, request, 28, nil_word, 0, reply,
                           190, received_len, nil_word, 0, nil_word,
                           packet_id, status);

    if status.all <> status_$ok then
      return;

    { the whole map }
    if received_len = 40 then begin
      for i := 0 to 0 do
        seg_map_out[i] := reply.seg_bits[i];
      return;
    end;

    { one segment's bits }
    if received_len = 12 then begin
      if start_seg = request.seg_index then
        for i := 0 to 0 do
          seg_map_out[i] := [];
      seg_offset := request.seg_index - start_seg;
      if reply.seg_bits[0] <> [] then
        for j := 0 to 31 do
          if j in reply.seg_bits[0] then
            seg_map_out[seg_offset] := seg_map_out[seg_offset] + [j];
      request.seg_index := request.seg_index + 1;
      if request.seg_index * 32768 > end_offset then
        return;
    end;

  until request.seg_index > start_seg;
end;
