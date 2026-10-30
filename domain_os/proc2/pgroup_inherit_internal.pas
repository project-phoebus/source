{ proc2_$pgroup_inherit_internal - give one entry another's process group.

  Image addresses:
    sau2  0x00E4216E  proc2_$pgroup_inherit_internal (module-local)

  - The source's group, if any, gains a reference, and its index is
    copied into the destination.

  Status stored: none.
}

procedure proc2_$pgroup_inherit_internal(in from_entry: proc2_info_t;
                                         var to_entry: proc2_info_t);
  internal;
var
  unused_8: array[1..2] of integer32;     { nothing reaches
                                            it; the TODO(pascal) below }
begin
  if from_entry.pgroup_table_idx <> 0 then
    proc2_$pgroup_table[from_entry.pgroup_table_idx].ref_count :=
      proc2_$pgroup_table[from_entry.pgroup_table_idx].ref_count + 1;

  to_entry.pgroup_table_idx := from_entry.pgroup_table_idx;
end;

{ TODO(pascal) proc2_$pgroup_inherit_internal's frame: the SAU2 frame is
  8 bytes with nothing addressed in it.  The
  routine has no local the image shows; unused_8 keeps the size.  What the
  original declared there is not recoverable from the code. }
