{ INTERRUPTER - the line whose controller interrupts.

  Image addresses:
    sau3  0x00E8563E  INTERRUPTER

  - The first present line whose control register shows an interrupt;
    false, with line past the last line, when there is none.

  Status stored: none.
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
function interrupter(out line: pinteger): boolean;
begin
  for line := 0 to iic_$max_line do
    with iic_lines[line] do
      if present and then (0 in csr^.status) then begin
        interrupter := true;
        return;
      end;
  interrupter := false;
end;
