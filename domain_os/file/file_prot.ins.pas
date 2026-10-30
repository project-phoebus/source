{ file/file_prot.ins.pas - FILE_$SET_PROT_INT and its value record, the
  FILE_ declarations that need ACL_'s protection record.

  file_$set_prot_rec_t's first view is acl/acl.ins.pas's
  acl_$prot_data_t, so neither file/file.ins.pas nor acl/acl.ins.pas
  can hold it, for their includers: an insert file of its own
  (ast/ast_acl.ins.pas's form).

  Include base, file and acl before it: file/file.pas and
  rem_file/rem_file.pas do.
}

type
  { The protection value FILE_$SET_PROT and FILE_$OLD_AP build for
    FILE_$SET_PROT_INT, 0x34 bytes: the 0x2C-byte protection record and
    the ACL's UID right behind it, which FILE_$SET_PROT_INT reads at
    +0x2C.  FILE_$SET_PROT_INT passes the whole as the attribute's value
    to AST_$SET_ATTRIBUTE and AST_$SET_ATTR (file/file.ins.pas
    file_$attr_value_t, the same 0x34 bytes): the second view.  A dpc
    probe gives acl_uid at 0x2C and the size 0x34. }
  file_$set_prot_rec_t = record
    case integer of
      1: (prot: acl_$prot_data_t;         { 0x00 }
          acl_uid: file_$uid_view_t);     { 0x2C }
      2: (value: file_$attr_value_t);     { 0x00 }
  end;

{ FILE_$SET_PROT_INT - set an object's protection, locally or on its node. }
procedure file_$set_prot_int(in file_uid: uid_$t;
                             in acl_data: file_$set_prot_rec_t;
                             attr_type: integer; prot_type: integer;
                             subsys_flag: boolean;
                             out status_ret: status_$t);
  options(extern, val_param);
