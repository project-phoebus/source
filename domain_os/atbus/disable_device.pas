{ ATBUS_$DISABLE_DEVICE - stop an AT bus interrupt from interrupting.

  Image addresses:
    sau7  0x3C40C26E  ATBUS_$DISABLE_DEVICE
    sau8  0x03C0B91A  ATBUS_$DISABLE_DEVICE
    sau9  0x3C40C8E8  ATBUS_$DISABLE_DEVICE

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  Its system bus level is disabled
    (SYSBUS_$DISABLE_DEVICE).
  - The check is ATBUS_$ENABLE_DEVICE's.
  - With `atbus_pics' the interrupt's controller input is masked;
    the vector word picks the controller, ATBUS_$INTLEV_VEC the input.

  Status stored: none.
}

%if atbus_pics %then
procedure atbus_$disable_device(id: io_$int_id_t);
  options(val_param);
var
  irq: pinteger;
begin
  irq := atbus_$intlev_vec[id.vector];
  if id.vector <= 7 then
    pic1.m_imr_bits := pic1.m_imr_bits + [irq]
  else
    pic1.s_imr_bits := pic1.s_imr_bits + [irq - 8];
end;
%else

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
%endif
