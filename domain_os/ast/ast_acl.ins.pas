{ ast/ast_acl.ins.pas - AST_$GET_ACL_ATTRIBUTES, the AST_ heading that
  needs ACL_'s record.

  Its record, ast_$acl_attr_t, is acl/acl.ins.pas's and its location
  record file/file.ins.pas's; neither ast/ast.ins.pas nor
  acl/acl.ins.pas can hold the heading, for their includers.  So it is
  an insert file of its own (dir/dir_server.ins.pas's form).

  Include base, file and acl before it: acl/acl.pas, dir/dir.pas,
  rem_file/rem_file.pas and ast/ast.pas do.
}

{ AST_$GET_ACL_ATTRIBUTES - an object's type bytes, ACL UID and protection
  block. }
procedure ast_$get_acl_attributes(var loc: file_$obj_loc_t; mode: integer;
                                  out attrs: ast_$acl_attr_t;
                                  out status: status_$t);
  options(extern, val_param);
