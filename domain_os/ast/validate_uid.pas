{ ast_$validate_uid - record a failed object lookup and return "not found".

  Image addresses:
    sau2  0x00E00BE8  ast_$validate_uid (module-local)
    sau9  0x3C401FC8  ast_$validate_uid (module-local)

  - The object's UID and the caller's tag longword go into
    AST_$NOT_FOUND, for post-mortem inspection.  Despite its name it
    validates nothing.
  - The result is file_$object_not_found (16#F0001).

  Status stored: none.
}

function ast_$validate_uid(in uid: uid_$t; flags: integer32): integer32;
  internal;
begin
  ast_$not_found.uid := uid;
  ast_$not_found.flags := flags;

  ast_$validate_uid := file_$object_not_found;
end;
