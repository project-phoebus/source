{ acl_$is_process_type_2 - whether a process's type is other than 2.

  Image addresses:
    sau2  0x00E46498  acl_$is_process_type_2 (module-local)

  - True when PROC1_$TYPE[pid] is not 2; the name says the opposite.

  Status stored: none.
}

function acl_$is_process_type_2(pid: integer): boolean; internal;
begin
  acl_$is_process_type_2 := proc1_$type[pid] <> 2;
end;
