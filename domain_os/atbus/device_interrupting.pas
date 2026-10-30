{ ATBUS_$DEVICE_INTERRUPTING - tell whether an AT bus interrupt is
  interrupting.

  Image addresses:
    sau9  0x3C40C944  ATBUS_$DEVICE_INTERRUPTING

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  The result is its system bus level's
    (SYSBUS_$DEVICE_INTERRUPTING).
  - The check is ATBUS_$ENABLE_DEVICE's.

  Status stored: none.
}

function atbus_$device_interrupting(id: io_$int_id_t): boolean;
  options(val_param);
var
  irq: pinteger;
  level: atbus_$int_level_t;
begin
  irq := id.vector;
  if irq > atbus_$max_irq then
    crash_system(status_$atbus_undefined_interrupt);
  level := atbus_irq_level[irq];
  if atbus_level_irq[level] <> irq then
    crash_system(status_$io_unit_not_acquired);
  atbus_$device_interrupting :=
    sysbus_$device_interrupting(atbus_sysbus_ids[level]);
end;
