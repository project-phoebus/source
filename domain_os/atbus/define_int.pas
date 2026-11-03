{ ATBUS_$DEFINE_INT - define an AT bus interrupt's handler.

  Image addresses:
    sau9  0x3C40C770  ATBUS_$DEFINE_INT
    sau8  0x03C0B86C  ATBUS_$DEFINE_INT

  - An interrupt above 15 crashes the system.  The handler goes on the
    interrupt's system bus level (SYSBUS_$DEFINE_INT), the interrupt
    selected for the level in the MMU's interrupt mask register.
  - Levels 1 and 3 share one select field: defining one while the other
    has an interrupt with another select value crashes the system.
  - A nil handler undefines the interrupt, which must be the level's:
    the level gets ATBUS_$UNDEF_INT with a nil argument.
  - Undefining an interrupt with no level (0, 1, 2, 8, 13) checks it
    against the word before atbus_level_irq.
  - With `atbus_pics' the handler and argument go into ATBUS_$INT_VEC
    at ATBUS_$INTLEV_VEC's entry for the id; no handler masks the
    interrupt and puts ATBUS_$UNDEF_INT there.

  Status stored: none.
}

%if atbus_pics %then
procedure atbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                            handler_arg: univ_ptr);
  options(val_param);
var
  irq: pinteger;
begin
  irq := atbus_$intlev_vec[id.vector];
  if irq > atbus_$max_irq then
    crash_system(status_$atbus_undefined_interrupt);
  if handler <> nil then begin
    atbus_$int_vec[irq].handler := handler;
    atbus_$int_vec[irq].handler_arg := handler_arg;
  end
  else begin
    atbus_$disable_device(id);
    atbus_$int_vec[irq].handler := addr(atbus_$undef_int);
  end;
end;
%else

procedure atbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                            handler_arg: univ_ptr);
  options(val_param);
var
  irq: pinteger;
  level: atbus_$int_level_t;
begin
  irq := id.vector;
  if irq > atbus_$max_irq then
    crash_system(status_$atbus_undefined_interrupt);
  level := atbus_irq_level[irq];
  if handler <> nil then begin
    { the interrupt must have a level, and the level be free }
    if not in_range(level) or else
       (atbus_level_irq[level] <= atbus_$max_irq) then
      crash_system(status_$io_int_id_in_use);
    if (level = 1) or else (level = 3) then begin
      { level 4 - level is the one that shares the select field }
      if (atbus_level_irq[4 - level] <= atbus_$max_irq) and then
         (mmu_$imr_copy.level13_select <> atbus_imr_select[irq]) then
        crash_system(status_$io_int_id_in_use);
      mmu_$imr_copy.level13_select := atbus_imr_select[irq];
    end
    else
      mmu_$imr_copy.level2_select := atbus_imr_select[irq];
    mmu_imr.all := mmu_$imr_copy.all;
    atbus_level_irq[level] := irq;
    sysbus_$define_int(atbus_sysbus_ids[level], handler, handler_arg);
  end
  else begin
    if atbus_level_irq[level] <> irq then
      crash_system(status_$io_unit_not_acquired);
    atbus_level_irq[level] := atbus_$no_irq;
    sysbus_$define_int(atbus_sysbus_ids[level], addr(atbus_$undef_int),
                       nil);
  end;
end;
%endif
