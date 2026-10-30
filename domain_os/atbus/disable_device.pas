{ ATBUS_$DISABLE_DEVICE - stop an AT bus interrupt from interrupting.

  Image addresses:
    sau9  0x3C40C8E8  ATBUS_$DISABLE_DEVICE

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  Its system bus level is disabled
    (SYSBUS_$DISABLE_DEVICE).
  - The check is ATBUS_$ENABLE_DEVICE's.

  Status stored: none.
}

procedure atbus_$disable_device(id: io_$int_id_t);
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
  sysbus_$disable_device(atbus_sysbus_ids[level]);
end;
