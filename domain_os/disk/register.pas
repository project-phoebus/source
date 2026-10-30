{ DISK_$REGISTER - enter a driver in the device table.

  Image addresses:
    sau2  0x00E3D9AC  DISK_$REGISTER

  - A driver whose jump table has a dinit and a do_io entry gets the
    first free slot of the 32-entry table (its type, controller, unit
    word, flags word and jump table).
  - The result is whether it got a slot.

  Status stored: none.
}

function disk_$register(in dev_type: integer; in ctlr: integer;
                        units: integer; in flags: integer;
                        in jump_table: univ_ptr): boolean;
var
  i: integer;
begin
  disk_$register := false;

  { the first free slot }
  if (disk_$jump_table_ptr_t(jump_table)^.dinit <> nil) and then
     (disk_$jump_table_ptr_t(jump_table)^.do_io <> nil) then
    for i := 1 to 32 do
      if disk_$devices[i].jump_table = nil then begin
        disk_$devices[i].device_type := dev_type;
        disk_$devices[i].controller := ctlr;
        disk_$devices[i].unit_count := units;
        disk_$devices[i].flags := flags;
        disk_$devices[i].jump_table := jump_table;
        disk_$register := true;
        return;
      end;
end;
