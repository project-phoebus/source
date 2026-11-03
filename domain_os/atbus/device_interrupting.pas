{ ATBUS_$DEVICE_INTERRUPTING - tell whether an AT bus interrupt is
  interrupting.

  Image addresses:
    sau9  0x3C40C944  ATBUS_$DEVICE_INTERRUPTING
    sau8  0x03C0B96C  ATBUS_$DEVICE_INTERRUPTING

  - An interrupt above 15 crashes the system; so does one that is not
    the one defined on its level.  The result is its system bus level's
    (SYSBUS_$DEVICE_INTERRUPTING).
  - The check is ATBUS_$ENABLE_DEVICE's.
  - With `atbus_pics' the interrupt's controller input is read from
    its request register.

  Status stored: none.
}

%if atbus_pics %then
function atbus_$device_interrupting(id: io_$int_id_t): boolean;
  options(val_param);
var
  irq: pinteger;
begin
  irq := atbus_$intlev_vec[id.vector];
  if irq <= 7 then begin
    pic1.m_cmd := atbus_$read_irr;
    atbus_$device_interrupting := irq in pic1.m_cmd_bits;
  end
  else begin
    pic1.s_cmd := atbus_$read_irr;
    atbus_$device_interrupting := (irq - 8) in pic1.s_cmd_bits;
  end;
end;
%else

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
%endif
