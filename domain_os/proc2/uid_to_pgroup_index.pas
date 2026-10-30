{ proc2_$uid_to_pgroup_index - a process group's table slot from a UID.

  Image addresses:
    sau2  0x00E42272  proc2_$uid_to_pgroup_index (module-local)

  - A group's UID (first byte 0) carries its UNIX id in its second word;
    any other UID is a process's, whose entry names its group.  The
    result is 0 when neither finds one.

  Status stored: none.
}

function proc2_$uid_to_pgroup_index(
           in pgroup_uid: univ proc2_pgroup_uid_view_t): integer;
var
  status: status_$t;
  index: integer;
  result_idx: integer;
  upgid: integer;
begin
  result_idx := 0;
  if pgroup_uid.first_byte = 0 then begin
    upgid := pgroup_uid.upgid;
    result_idx := pgroup_find_by_upgid(upgid);
  end
  else begin
    index := proc2_$find_index(pgroup_uid.uid, status);
    if status.all = status_$ok then
      result_idx := proc2_$info_table[index].pgroup_table_idx;

  end;
  proc2_$uid_to_pgroup_index := result_idx;
end;
