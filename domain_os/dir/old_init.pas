{ DIR_$OLD_INIT - mark the processes as holding no old-format directory
  lock.

  Image addresses:
    sau2  0x00E314F4  DIR_$OLD_INIT

  - The loop clears entries 0..57.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure dir_$old_init;
var
  i: integer;
begin
  for i := 0 to 57 do
    name_$lock_uid[i].high := 0;
end;
