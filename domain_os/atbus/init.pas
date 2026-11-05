{ ATBUS_$INIT - set the AT bus's interrupts up at boot.

  Image addresses:
    sau7  0x3C43796C  ATBUS_$INIT
    sau8  0x03C32154  ATBUS_$INIT
    sau9  0x3C4350BC  ATBUS_$INIT

  - Each of the system bus levels 1..3 gets ATBUS_$UNDEF_INT, with the
    level as its argument, and no interrupt defined.
  - With `atbus_pics' the vectors 16#A0..16#AF are trapped to
    ATBUS_$INT and the two controllers programmed, everything masked
    but the master's inputs 0, 1 and 3 (and, with
    `atbus_irq8_unmasked', the slave's input 0).

  Status stored: none.
}

%if atbus_pics %then
[section(os_init_proc, os_init_data)]
procedure atbus_$init;
var
  i: integer;
begin
  for i := 0 to atbus_$max_irq do
    io_$trap(atbus_$first_vector + i, addr(atbus_$int));

  { the controllers: master, then slave; all masked, then the master's
    run mask }
  with pic1 do begin
    m_cmd := atbus_$icw1;
    m_imr := atbus_$m_vector_base;
    m_imr := atbus_$m_cascade;
    m_imr := atbus_$icw4;
    m_imr := atbus_$mask_all;
    s_cmd := atbus_$icw1;
    s_imr := atbus_$s_vector_base;
    s_imr := atbus_$s_cascade_id;
    s_imr := atbus_$icw4;
    s_imr := atbus_$mask_all;
    m_imr := atbus_$m_mask_run;
%if atbus_irq8_unmasked %then
    s_imr := atbus_$s_mask_run;
%else
    s_imr := atbus_$mask_all;
%endif
  end;
end;
%else

[section(os_init_proc, os_init_data)]
procedure atbus_$init;
var
  level: integer32;
begin
  for level := 1 to atbus_$n_levels do begin
    sysbus_$define_int(atbus_sysbus_ids[level], addr(atbus_$undef_int),
                       univ_ptr(level));
    atbus_level_irq[level] := atbus_$no_irq;
  end;
end;
%endif
