{ NAME_$SET_ACL - set an object's ACL.

  Image addresses:
    sau2  0x00E58656  NAME_$SET_ACL

  - DIR_$SET_ACL with the same three arguments.

  Status stored:
    dir_$set_acl's status: always
}

{ TODO(pascal) 8 frame bytes of NAME_$SET_ACL no object explains

  The SAU2 frame has 8 bytes in a global routine that addresses no frame
  byte: an 8-byte local or two longwords nothing reads or writes
  (stand-in unused_8).  A value parameter copied at entry would show its
  copy; none is made, and the slots are passed on as they are. }

procedure name_$set_acl(in uid: uid_$t; in acl: uid_$t;
                        out status: status_$t);
var
  unused_8: array[1..8] of char;          { the TODO above }
begin
  dir_$set_acl(uid, acl, status);
end;
