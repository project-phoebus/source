{ proc2_$entry_pgroup_upgid - an entry's process group's UNIX id.

  Image addresses:
    sau2  0x00E421AA  proc2_$entry_pgroup_upgid (module-local)

  - The group's upgid, 0 with no group.

  Status stored: none.
}

procedure proc2_$entry_pgroup_upgid(in entry: proc2_info_t;
                                    out upgid_ret: pinteger);
begin
  if entry.pgroup_table_idx = 0 then
    upgid_ret := 0
  else
    upgid_ret :=
      proc2_$pgroup_table[entry.pgroup_table_idx].upgid;
end;
