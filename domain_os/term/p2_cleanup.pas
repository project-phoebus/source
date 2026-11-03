{ TERM_$P2_CLEANUP - drop a dying process's ownership of the terminal
  lines.

  Image addresses:
    sau2  0x00E751F0  TERM_$P2_CLEANUP
    sau3  0x00E76790  TERM_$P2_CLEANUP
    sau8  0x03C7FD34  TERM_$P2_CLEANUP
    sau9  0x3C47CD74  TERM_$P2_CLEANUP

  - Each line's TTY descriptor (three, four with `sio16550_lines') whose
    process group is the dying process's UID gets UID_$NIL.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure term_$p2_cleanup(in as_id: integer);
var
  i: integer;
begin
  for i := 1 to term_$n_lines do
    if tty_descs[i].pgroup_uid = proc2_$uid[as_id] then
      tty_descs[i].pgroup_uid := uid_$nil;
end;
