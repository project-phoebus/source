{ ATBUS_$INIT - set the AT bus's interrupts up at boot.

  Image addresses:
    sau9  0x3C4350BC  ATBUS_$INIT

  - Each of the system bus levels 1..3 gets ATBUS_$UNDEF_INT, with the
    level as its argument, and no interrupt defined.

  Status stored: none.
}

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
