{ FILE_$FW_PARTIAL - force-write a byte range of an object.

  Image addresses:
    sau2  0x00E5E680  FILE_$FW_PARTIAL

  - AST_$PURIFY writes the range a 32 KB segment at a time, from the
    start offset's segment on, with the flags 3 if the object is in the
    lock table, 16#8003 if not; a failed purify ends the loop.

  Status stored:
    status_$ok: an empty range
    ast_$purify's status: the last segment
}

procedure file_$fw_partial(in file_uid: uid_$t; in start_offset: linteger;
                           in length: integer32;
                           out status_ret: status_$t);
var
  flags: integer;
  result: boolean;
  remaining: integer32;
  chunk: integer32;
  seg: integer;
begin
  status_ret.all := status_$ok;

  chunk := 16#8000 - (start_offset & 16#7FFF);
  seg := rshft(start_offset, 15);
  remaining := length;

  if file_$delete_int(file_uid, 0, result, status_ret) then
    flags := 3
  else
    flags := -16#7FFD;                    { 16#8003 }

  while remaining > 0 do begin
    ast_$purify(file_uid, flags, seg, 0, 0, status_ret);
    if status_ret.all <> status_$ok then
      exit;
    remaining := remaining - chunk;
    chunk := 16#8000;
    seg := seg + 1;
  end;
end;
