{ SYSBUS_$DISABLE_DEVICE - stop a system bus level from interrupting.

  Image addresses:
    sau9  0x3C40C5C8  SYSBUS_$DISABLE_DEVICE

  - The id's vector, 16#A0..16#AF, names the level; another vector
    crashes the system.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `util_pic'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sysbus_$disable_device(id: io_$int_id_t);
  options(val_param);
var
  vector: integer;
  level: sysbus_$level_t;
begin
  vector := id.vector;
  if (vector >= sysbus_$first_vector) and then
     (vector <= sysbus_$last_vector) then
    level := vector - sysbus_$first_vector
  else
    crash_system(status_$sysbus_unknown_interrupt_id);
  if level < sysbus_$first_hi_level then
    util_pic.enable_lo := util_pic.enable_lo - [level]
  else
    util_pic.enable_hi :=
      util_pic.enable_hi - [level - sysbus_$first_hi_level];
end;
