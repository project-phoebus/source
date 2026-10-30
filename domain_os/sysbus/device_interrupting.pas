{ SYSBUS_$DEVICE_INTERRUPTING - tell whether a system bus level is
  interrupting.

  Image addresses:
    sau9  0x3C40C62E  SYSBUS_$DEVICE_INTERRUPTING

  - The id's vector, 16#A0..16#AF, names the level; another vector
    crashes the system.  The result is the level's pending bit.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `util_pic'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function sysbus_$device_interrupting(id: io_$int_id_t): boolean;
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
    sysbus_$device_interrupting := level in util_pic.pending_lo
  else
    sysbus_$device_interrupting :=
      (level - sysbus_$first_hi_level) in util_pic.pending_hi;
end;
