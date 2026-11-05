{ AST_$SET_TROUBLE - DXM callback: mark a clobbered object as in trouble.

  Image addresses:
    sau2  0x00E071EA  AST_$SET_TROUBLE
    sau7  0x3C407E44  AST_$SET_TROUBLE
    sau9  0x3C408644  AST_$SET_TROUBLE

  - Run from DXM_$UNWIRED_Q with the UID AST_$SAVE_CLOBBERED_UID queued:
    the object's trouble attribute (2) is set to true through
    AST_$SET_ATTRIBUTE, its status not read.
  - TODO(pascal): value's 8-byte alignment, which dpc does not give
    here.

  Status stored: none.
}

procedure ast_$set_trouble(in uid_ptr: ast_uid_ptr_t);
var
  value: file_$attr_value_t;
  uid: ast_uid_ptr_t;
  status: status_$t;
begin
  uid := uid_ptr;
  value.flag := true;

  ast_$set_attribute(uid^, 2, value, status);
end;
