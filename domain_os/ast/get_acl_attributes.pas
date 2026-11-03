{ AST_$GET_ACL_ATTRIBUTES - an object's type bytes, ACL UID and
  protection block.

  Image addresses:
    sau2  0x00E04AAA  AST_$GET_ACL_ATTRIBUTES
    sau4  0x0F804E56  AST_$GET_ACL_ATTRIBUTES
    sau9  0x3C405D7E  AST_$GET_ACL_ATTRIBUTES

  - From AST_$GET_ATTRIBUTES' full record: its first four bytes, its ACL
    UID (+0x88) and its 44-byte protection block (+0x48), into the
    caller's 56-byte record.

  Status stored:
    ast_$get_attributes's status: in either case
}

procedure ast_$get_acl_attributes(var loc: file_$obj_loc_t; mode: integer;
                                  out attrs: ast_$acl_attr_t;
                                  out status: status_$t);
var
  full: ast_$attr_rec_t;
begin
  ast_$get_attributes(loc, mode, full.fattr, status);

  attrs.hdr := full.fattr.word_00;
  attrs.default_acl := full.sa.acl_uid;
  attrs.prot := full.sa.pv.prot;
end;
