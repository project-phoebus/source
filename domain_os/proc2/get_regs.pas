{ PROC2_$GET_REGS - a process's registers: a stub that refuses.

  Image addresses:
    sau2  0x00E41D9E  PROC2_$GET_REGS

  - None of the first five arguments is read.

  Status stored:
    status_$proc2_permission_denied: always
}

procedure proc2_$get_regs(in proc_uid: uid_$t; in arg2: integer32;
                          in arg3: integer32; in arg4: integer32;
                          in arg5: integer32;
                          out status_ret: status_$t);
var
  unused_98: array[1..152] of char;       { nothing reaches
                                            them; the TODO(pascal) below }
  unused_9c: integer32;
begin
  status_ret.all := status_$proc2_permission_denied;
end;

{ TODO(pascal) PROC2_$GET_REGS's frame has 156 bytes nothing addresses

  The original's locals are not known; the stand-ins unused_98 (152
  bytes, at a multiple of 8 from A6) and unused_9c (a longword) keep the
  frame's size.  One 156-byte object would be placed at a multiple of 8
  and take 160 bytes, so the original's objects there were smaller. }
