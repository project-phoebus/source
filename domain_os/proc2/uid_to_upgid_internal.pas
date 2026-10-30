{ proc2_$uid_to_upgid_internal - the UNIX group id of a group UID.

  Image addresses:
    sau2  0x00E422CC  proc2_$uid_to_upgid_internal (module-local)

  - A group's synthetic UID (first byte 0) carries the id at +2; another
    UID's process gives its group's id, 0 when the lookup fails or it has
    no group.

  Status stored: none.
}

function proc2_$uid_to_upgid_internal(
           in uid: univ proc2_pgroup_uid_view_t): pinteger;
var
  status: status_$t;
  upgid: pinteger;
  idx: integer;
  pgroup_idx: integer;
begin
  upgid := 0;
  if uid.first_byte = 0 then
    upgid := uid.upgid
  else begin
    idx := proc2_$find_index(uid.uid, status);
    if status.all = status_$ok then begin
      pgroup_idx := proc2_$info_table[idx].pgroup_table_idx;

      if pgroup_idx <> 0 then
        upgid := proc2_$pgroup_table[pgroup_idx].upgid;
    end;
  end;
  proc2_$uid_to_upgid_internal := upgid;
end;
