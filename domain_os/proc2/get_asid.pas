{ PROC2_$GET_ASID - the address space of a process UID.

  Image addresses:
    sau2  0x00E40702  PROC2_$GET_ASID

  - PROC2_$FIND_ASID with use_alt false; its result is this routine's.

  Status stored:
    proc2_$find_asid's status: always
}

function proc2_$get_asid(in proc_uid: uid_$t;
                         out status_ret: status_$t): integer;
begin
  proc2_$get_asid := proc2_$find_asid(proc_uid, false,
                                      status_ret);
end;
