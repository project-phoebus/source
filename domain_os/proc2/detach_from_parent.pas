{ proc2_$detach_from_parent - unlink a process from its parent.

  Image addresses:
    sau2  0x00E40DF4  proc2_$detach_from_parent (module-local)

  - The child leaves its parent's list and its parent link is cleared
    (none crashes the system); a zombie is released to the free list, a
    live process gets member 15 of its flags.
  - The next allocated entry's back link is written without a zero test.

  Status stored: none.
}

procedure proc2_$detach_from_parent(child_idx: integer;
                                    prev_sibling_idx: integer);
begin
  with proc2_$info_table[child_idx] do begin
    if parent_pgroup_idx <> 0 then begin
      if prev_sibling_idx = 0 then
        proc2_$info_table[parent_pgroup_idx].first_child_idx :=
          next_child_sibling
      else
        proc2_$info_table[prev_sibling_idx].next_child_sibling :=
          next_child_sibling;
      parent_pgroup_idx := 0;
    end
    else
      crash_system(status_$proc2_internal_error);
    if proc2_pf_zombie in flags.bits then begin
      pgroup_cleanup_internal(proc2_$info_table[child_idx], 1);

      if pad_14 = 0 then
        p2_info_alloc_ptr := next_index
      else
        proc2_$info_table[pad_14].next_index := next_index;
      proc2_$info_table[next_index].pad_14 := pad_14;
      next_index := proc2_$free_list_head;
      proc2_$free_list_head := child_idx;
    end
    else
      flags.bits := flags.bits + [proc2_pf_init];
  end;
end;
