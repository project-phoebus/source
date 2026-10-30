{ pgroup_find_by_upgid - a process group's table slot from its UNIX id.

  Image addresses:
    sau2  0x00E42224  pgroup_find_by_upgid (module-local)

  - The 70 slots in use are scanned for the UNIX group id; the result is
    the index, 0 for none.  The compare is mixed: the id widened signed,
    the table's unsigned.

  Status stored: none.
}

function pgroup_find_by_upgid(wanted_upgid: integer): integer;
var
  i: integer;
  unused_10: integer32;                   { nothing reaches it; the
                                            TODO(pascal) below }
begin
  for i := 1 to 70 do
    with proc2_$pgroup_table[i] do
      if (ref_count <> 0)
         and then (upgid = wanted_upgid) then begin
        pgroup_find_by_upgid := i;
        return;
      end;
  pgroup_find_by_upgid := 0;
end;

{ TODO(pascal) pgroup_find_by_upgid's frame: the SAU2 frame is 0x10 bytes
  with nothing addressed; dpc's frame for i and the loop is 0xC. The 4-byte stand-in
  unused_10 keeps the size; it is probably the home of the `with''s element
  address, which the original compiler gives a slot and dpc does not.  Settle
  with the other unaddressed frames. }
