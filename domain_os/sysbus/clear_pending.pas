{ SYSBUS_$CLEAR_PENDING - clear a system bus level's pending interrupt.

  Image addresses:
    sau9  0x3C40C67E  SYSBUS_$CLEAR_PENDING

  - The id's vector, 16#A0..16#AF, names the level; another vector
    crashes the system.  Only the level's bit is written as 1, which
    clears it and leaves the others.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `util_pic'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sysbus_$clear_pending(id: io_$int_id_t);
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
    util_pic.pending_lo := [level]
  else
    util_pic.pending_hi := [level - sysbus_$first_hi_level];
end;
