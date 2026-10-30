{ PROC2_$GET_MY_UPIDS - return the current process's UNIX ids.

  Image addresses:
    sau2  0x00E73968  PROC2_$GET_MY_UPIDS
    sau9  0x3C47B2DA  PROC2_$GET_MY_UPIDS

  - Its own id, its parent's (1 with none) and its process group's (0
    with none); no lock is taken.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$get_my_upids(out upid_ret: integer; out uppid_ret: integer;
                              out upgid_ret: integer);
var
  idx: integer;
begin
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    upid_ret := upid;
    if parent_pgroup_idx <> 0 then
      with proc2_$info_table[parent_pgroup_idx] do
        uppid_ret := upid
    else
      uppid_ret := 1;
    if pgroup_table_idx <> 0 then
      with proc2_$pgroup_table[pgroup_table_idx] do
        upgid_ret := upgid
    else
      upgid_ret := 0;
  end;
end;
