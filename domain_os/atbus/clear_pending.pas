{ ATBUS_$CLEAR_PENDING - clear an AT bus interrupt's pending interrupt.

  Image addresses:
    sau9  0x3C40C9A0  ATBUS_$CLEAR_PENDING
    sau8  0x03C0B9C2  ATBUS_$CLEAR_PENDING

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  Its system bus level's pending
    interrupt is cleared (SYSBUS_$CLEAR_PENDING).
  - The check is ATBUS_$ENABLE_DEVICE's.
  - With `atbus_pics' it does nothing: the controllers are told the
    end of each interrupt by ATBUS_$INT.

  Status stored: none.
}

%if atbus_pics %then
procedure atbus_$clear_pending(id: io_$int_id_t);
  options(val_param);
begin
end;
%else

procedure atbus_$clear_pending(id: io_$int_id_t);
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
  sysbus_$clear_pending(atbus_sysbus_ids[level]);
end;
%endif
