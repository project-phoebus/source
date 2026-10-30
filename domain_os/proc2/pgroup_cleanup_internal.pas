{ pgroup_cleanup_internal - drop a process's process-group references.

  Image addresses:
    sau2  0x00E420B8  pgroup_cleanup_internal (module-local)
    sau2  0x00E42028  pgroup_decr_leader_count (nested)

  - Unless mode is 1, a parent or child in another group of the same
    session makes that group lose a leader (the nested
    pgroup_decr_leader_count); unless mode is 0, the group loses the
    process's reference.

  Status stored: none.
}

procedure pgroup_cleanup_internal(var entry: proc2_info_t;
                                         mode: integer);
var
  status: status_$t;                      { the nested
                                            routine's calls' }
  parent: proc2_info_ptr_t;
  child: proc2_info_ptr_t;
  child_idx: integer;
  child_pgroup: pinteger;

  { pgroup_decr_leader_count - drop one leader from a process group.

    - A group whose leader count reaches 0 with a stopped member is sent
      SIGHUP and then SIGCONT (22) without the permission check
      (4.3BSD's orphaned process group rule).
    - Nested in pgroup_cleanup_internal.

    Status stored (in the parent's status):
      the signals' statuses: a group was signaled }
  procedure pgroup_decr_leader_count(pgroup_idx: integer);
  var
    unused_4: integer32;                  { nothing reaches it; the
                                            TODO(pascal) below the
                                            routine }
    index: integer;
    stopped: boolean;
  begin
    if pgroup_idx = 0 then
      return;
    with proc2_$pgroup_table[pgroup_idx] do begin
      leader_count := leader_count - 1;
      if leader_count <> 0 then
        return;
    end;
    stopped := false;
    index := p2_info_alloc_ptr;
    if index <> 0 then
      repeat
        with proc2_$info_table[index] do begin
          if (proc2_pf_stopped in flags.bits)
             and then (pgroup_table_idx = pgroup_idx) then
            stopped := true;
          index := next_index;
        end;
      until index = 0;
    if stopped then begin
      proc2_$signal_pgroup_internal(pgroup_idx, proc2_$sig_hup,
                                    status_$t(integer32(0)), false,
                                    status);
      proc2_$signal_pgroup_internal(pgroup_idx, proc2_$sig_cont,
                                    status_$t(integer32(0)), false,
                                    status);
    end;
  end;

begin
  if entry.pgroup_table_idx <> 0 then
    with proc2_$pgroup_table[entry.pgroup_table_idx] do begin

      parent := addr(proc2_$info_table[entry.parent_pgroup_idx]);

      if mode <> 1 then begin
        if (entry.parent_pgroup_idx <> 0)
           and then (parent^.pgroup_table_idx
                     <> entry.pgroup_table_idx)
           and then (parent^.session_id = entry.session_id) then

          pgroup_decr_leader_count(entry.pgroup_table_idx);
        child_idx := entry.first_child_idx;
        if child_idx <> 0 then
          repeat
            child := addr(proc2_$info_table[child_idx]);
            child_pgroup := child^.pgroup_table_idx;
            if (child_pgroup <> entry.pgroup_table_idx)
               and then (child^.session_id = entry.session_id) then

              pgroup_decr_leader_count(child_pgroup);
            child_idx := child^.next_child_sibling;
          until child_idx = 0;
      end;
      if mode <> 0 then begin
        ref_count := ref_count - 1;
        entry.pgroup_table_idx := 0;
      end;
    end;
end;

{ TODO(pascal) pgroup_cleanup_internal's nested pgroup_decr_leader_count
  has a frame of 20 bytes nothing addresses; its parameter's copy, two
  register-held locals and two `with' temporaries take 16 in dpc's layout,
  and the other 4 are not explained (the routine's status is, in the image,
  the parent's local); the stand-in unused_4 keeps the size. }
