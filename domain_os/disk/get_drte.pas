{ DISK_$GET_DRTE - find a driver's entry in the device table.

  Image addresses:
    sau2  0x00E3DA1C  DISK_$GET_DRTE

  - The first registered entry with the given controller type and
    number, or nil.

  Status stored: none.
}

function disk_$get_drte(in ctype: integer; in cnum: integer):
  disk_$device_entry_ptr_t;
var
  i: integer;
begin
  disk_$get_drte := nil;

  for i := 1 to 32 do
    with disk_$devices[i] do
      if (jump_table <> nil) and then (device_type = ctype) and then
         (controller = cnum) then begin
        disk_$get_drte := addr(disk_$devices[i]);
        return;
      end;
end;
