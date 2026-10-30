{ proc2_$wait_reap_child - free a dead child's entry and report its exit.

  Image addresses:
    sau2  0x00E3FB34  proc2_$wait_reap_child (module-local)

  Assume we're called with ml_$proc2_lock held.

  - The child's debugging ends; its entry leaves the allocated list, its
    parent's list (unless the init process) and its group, and joins the
    free list.  The zombie's exit report and UNIX pid are handed back.

  Status stored: none.
}

procedure proc2_$wait_reap_child(child_idx: integer;
                                 parent_idx: integer;
                                 prev_sibling: integer;
                                 out result: proc2_$wait_result_t;
                                 out pid_ret: integer); internal;
begin
  with proc2_$info_table[child_idx] do begin
    if debugger_idx <> 0 then
      debug_clear_internal(self_index, false);
    if pad_14 = 0 then
      p2_info_alloc_ptr := next_index
    else
      proc2_$info_table[pad_14].next_index := next_index;
    proc2_$info_table[next_index].pad_14 := pad_14;
    if not (proc2_pf_init in flags.bits) then
      if prev_sibling = 0 then
        proc2_$info_table[parent_idx].first_child_idx :=
          next_child_sibling
      else
        proc2_$info_table[prev_sibling].next_child_sibling :=
          next_child_sibling;
    pgroup_cleanup_internal(proc2_$info_table[child_idx], 1);

    flags.bits := flags.bits - [proc2_pf_zombie];
    next_index := proc2_$free_list_head;
    proc2_$free_list_head := child_idx;
    result.exit := zombie_exit;
    result.usage := zombie_usage;
    result.parent_uid := parent_uid;
    result.entry_60 := zombie_counts;
    result.flag_65 := 15 in zombie_flags.bits;
    result.flag_66 := 14 in zombie_flags.bits;
    pid_ret := upid;
  end;
end;
