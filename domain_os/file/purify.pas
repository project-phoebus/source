{ FILE_$PURIFY - write an object's modified pages back.

  Image addresses:
    sau2  0x00E5E5F2  FILE_$PURIFY

  - AST_$PURIFY with no flags, segment 0, the literal 0 as its page list
    and no list count.

  Status stored:
    ast_$purify's status: in either case
}

procedure file_$purify(in file_uid: uid_$t; out status_ret: status_$t);
begin
  ast_$purify(file_uid, 0, 0, 0, 0, status_ret);
end;
