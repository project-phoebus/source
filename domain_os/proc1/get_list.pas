{ PROC1_$GET_LIST - the bound processes with no address space.

  Image addresses:
    sau2  0x00E15362  PROC1_$GET_LIST
    sau4  0x0F815BD6  PROC1_$GET_LIST
    sau6  0x78015AC6  PROC1_$GET_LIST
    sau7  0x3C41701E  PROC1_$GET_LIST

  - Each PCB that exists, is bound and has address space 0 adds its pid
    and type to the list.

  Status stored: none.
}

procedure proc1_$get_list(out count_ret: integer; out list_ret: proc1_$list_t);
var
  i: integer;
begin
  count_ret := 0;
  for i := 0 to 64 do
    if (pcbs[i] <> nil) and then
       (proc1_flag_bound in pcbs[i]^.flags) and then
       (pcbs[i]^.asid = 0) then begin
      count_ret := count_ret + 1;
      list_ret[count_ret].pid := pcbs[i]^.mypid;
      list_ret[count_ret].proc_type := proc1_$type[pcbs[i]^.mypid];
    end;
end;
