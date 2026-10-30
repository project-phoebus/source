{ ATBUS_$ENABLE_DEVICE - let an AT bus interrupt interrupt.

  Image addresses:
    sau9  0x3C40C88C  ATBUS_$ENABLE_DEVICE

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  Its system bus level is enabled
    (SYSBUS_$ENABLE_DEVICE).
  - An interrupt with no level (0, 1, 2, 8, 13) is checked against the
    word before atbus_level_irq.

  Status stored: none.
}

procedure atbus_$enable_device(id: io_$int_id_t);
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
  sysbus_$enable_device(atbus_sysbus_ids[level]);
end;
