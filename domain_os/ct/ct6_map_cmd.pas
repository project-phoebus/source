{ ct6_map_cmd - the second controller's operation for a tape command.

  Image addresses:
    sau6  0x7807DC48  ct6_map_cmd (module-local)

  - The command is looked up in ct6_cmd_map; a command the table does
    not hold crashes the system with "illegal drive command".

  Returns:
    true: always (the callers test it)

  Status stored: none.
}

function ct6_map_cmd(cmd: integer; out op: integer): boolean; internal;
label
  1;
var
  i: integer;
begin
  for i := 1 to ct6_cmd_map_size do
    if ct6_cmd_map[i].cmd = cmd then begin
      op := ct6_cmd_map[i].op;
      goto 1;
    end;
  crash_system(status_$ct_illegal_drive_command);
1:
  ct6_map_cmd := true;
end;
