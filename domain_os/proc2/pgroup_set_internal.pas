{ pgroup_set_internal - move a process into a process group.

  Image addresses:
    sau2  0x00E41E86  pgroup_set_internal (module-local)

  - A zero group id drops the process's group.  Otherwise an existing
    group gains a reference, or a free slot is set up (none crashes the
    system); the old group loses its reference.
  - Leader counts follow the parent and children in the same session;
    the process's group index becomes the new slot's.

  Status stored:
    status_$ok: the process was moved
    status_$proc2_pgroup_in_different_session: the group is in another
      session (nothing changes)
}

procedure pgroup_set_internal(var entry: proc2_info_t;
                              new_upgid: integer;
                              out status_ret: status_$t);
var
  unused_14: array[1..5] of integer32;    { nothing reaches
                                            it; the TODO(pascal) below }
  new_idx: integer;
  i: integer;
  child_pgroup: pinteger;
  other: proc2_info_ptr_t;
begin
  status_ret.all := status_$ok;
  if new_upgid = 0 then begin
    pgroup_cleanup_internal(entry, 2);
    entry.pgroup_table_idx := 0;
    return;
  end;
  new_idx := pgroup_find_by_upgid(new_upgid);
  if new_idx <> 0 then begin
    if entry.session_id
       <> proc2_$pgroup_table[new_idx].session_id then begin

      status_ret.all := status_$proc2_pgroup_in_different_session;

      return;
    end;
    proc2_$pgroup_table[new_idx].ref_count :=
      proc2_$pgroup_table[new_idx].ref_count + 1;
  end
  else begin
    for new_idx := 1 to 70 do
      if proc2_$pgroup_table[new_idx].ref_count = 0 then
        exit;
    if new_idx > 70 then begin
      crash_system(status_$proc2_process_using_pgroup_id);
      entry.pgroup_table_idx := 0;
      return;
    end;
    with proc2_$pgroup_table[new_idx] do begin
      ref_count := 1;
      leader_count := 0;
      upgid := new_upgid;
      session_id := entry.session_id;
    end;
  end;
  if entry.pgroup_table_idx <> 0 then
    proc2_$pgroup_table[entry.pgroup_table_idx].ref_count :=
      proc2_$pgroup_table[entry.pgroup_table_idx].ref_count - 1;

  if entry.parent_pgroup_idx <> 0 then begin
    other := addr(proc2_$info_table[entry.parent_pgroup_idx]);

    if entry.session_id = other^.session_id then begin
      if (entry.pgroup_table_idx <> 0)
         and then (entry.pgroup_table_idx
                   <> other^.pgroup_table_idx) then
        proc2_$pgroup_table[entry.pgroup_table_idx].leader_count :=
          proc2_$pgroup_table[entry.pgroup_table_idx].leader_count - 1;

      if new_idx <> other^.pgroup_table_idx then
        proc2_$pgroup_table[new_idx].leader_count :=
          proc2_$pgroup_table[new_idx].leader_count + 1;
    end;
  end;
  i := entry.first_child_idx;
  if i <> 0 then
    repeat
      other := addr(proc2_$info_table[i]);
      if entry.session_id = other^.session_id then begin
        child_pgroup := other^.pgroup_table_idx;
        if (child_pgroup <> 0)
           and then (child_pgroup = entry.pgroup_table_idx) then

          proc2_$pgroup_table[child_pgroup].leader_count :=
            proc2_$pgroup_table[child_pgroup].leader_count + 1;

        if new_idx = other^.pgroup_table_idx then
          proc2_$pgroup_table[other^.pgroup_table_idx].leader_count :=
            proc2_$pgroup_table[other^.pgroup_table_idx].leader_count
            - 1;
      end;
      i := other^.next_child_sibling;
    until i = 0;
  entry.pgroup_table_idx := new_idx;
end;

{ TODO(pascal) pgroup_set_internal's frame has 40 bytes nothing
  addresses: more than the homes of its four register-held
  locals and its `with' temporary, 20 bytes in dpc's layout; the
  stand-in unused_14 makes up the other 20.  The original's other locals
  are not known. }
