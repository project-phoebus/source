{ proc2_$entry_pgroup_uid - an entry's process group's UID.

  Image addresses:
    sau2  0x00E421DE  proc2_$entry_pgroup_uid (module-local)

  - UID_$NIL with no group; else a zero word, the group's upgid and a
    zero longword.

  Status stored: none.
}

procedure proc2_$entry_pgroup_uid(in entry: proc2_info_t;
                                  out uid_ret: univ proc2_pgroup_uid_view_t);
begin
  if entry.pgroup_table_idx = 0 then
    uid_ret.uid := uid_$nil
  else begin
    uid_ret.zero := 0;
    uid_ret.upgid :=
      proc2_$pgroup_table[entry.pgroup_table_idx].upgid;
    uid_ret.low := 0;
  end;
end;
