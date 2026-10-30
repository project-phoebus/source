{ PROC2_$DELETE - delete the current process.

  Image addresses:
    sau2  0x00E74398  PROC2_$DELETE
    sau9  0x3C47BD18  PROC2_$DELETE

  - Everything is released through proc2_$delete_cleanup and the
    level-1 process unbound; an unbind that returns crashes the system,
    again and again.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure proc2_$delete;
var
  status: status_$t;
begin
  proc2_$delete_cleanup;
  repeat
    proc1_$unbind(proc1_$current, status);
    crash_system(status);
  until false;
end;
