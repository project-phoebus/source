{ DIR_$FIND_NET - the extra longword of a directory's entry for a node.

  Image addresses:
    sau2  0x00E4E8B4  DIR_$FIND_NET

  - The result is the entry's extra longword, 0 when the search failed.

  Status stored: none.
}

function dir_$find_net(in dir_uid: uid_$t; in index: linteger): integer32;
var
  target: dir_$node_uid_t;
  status: status_$t;
  net_ret: integer32;
  name_len: integer;
  name_buf: array[1..2] of char;
begin
  target.low.node := index;

  dir_$find_uid_internal(dir_uid, target.uid, true, 0, name_buf, name_len,
                         net_ret, status);

  dir_$find_net := net_ret;
  if status.all <> status_$ok then
    dir_$find_net := 0;
end;
