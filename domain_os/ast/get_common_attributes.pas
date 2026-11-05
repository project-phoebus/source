{ AST_$GET_COMMON_ATTRIBUTES - the common subset of an object's
  attributes.

  Image addresses:
    sau2  0x00E04A00  AST_$GET_COMMON_ATTRIBUTES
    sau4  0x0F804DAC  AST_$GET_COMMON_ATTRIBUTES
    sau6  0x7800508C  AST_$GET_COMMON_ATTRIBUTES
    sau7  0x3C4054EA  AST_$GET_COMMON_ATTRIBUTES
    sau9  0x3C405CEA  AST_$GET_COMMON_ATTRIBUTES

  - From AST_$GET_ATTRIBUTES' full record: its first four bytes, its
    length, its twelve bytes at +0x3C, its reference count and four flag
    bits of its byte +0x65, into the caller's 24-byte record.

  Status stored:
    ast_$get_attributes's status: in either case
}

procedure ast_$get_common_attributes(var loc_rec: file_$obj_loc_t;
                                     flags: integer;
                                     out attrs: ast_$common_attr_t;
                                     out status: status_$t);
var
  full: ast_$attr_rec_t;
begin
  ast_$get_attributes(loc_rec, flags, full.fattr, status);

  attrs.hdr := full.fattr.word_00;
  attrs.length := full.fattr.length;
  attrs.id12 := full.id12;
  attrs.refcount := full.fattr.link_count;

  attrs.acc.os_only := full.fattr.ext.ext_7;
  attrs.acc.mode_6 := full.fattr.ext.ext_6;
  attrs.hi.mode_5 := full.fattr.ext.ext_5;
  attrs.hi.mode_4 := full.fattr.ext.ext_4;
end;
