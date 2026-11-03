{ IIC_$PROC2_CLEANUP - release a line an ending address space owns (the
  driver record's proc2_cleanup).

  Image addresses:
    sau3  0x00E767F8  IIC_$PROC2_CLEANUP

  - A present line in use that asid owns is released.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure iic_$proc2_cleanup(in line: pinteger; asid: integer);
  options(val_param);
var
  st: status_$t;
begin
  if line <= iic_$max_line then
    with iic_lines[line] do
      if present and then (state <> iic_line_free) and then
         (owner = asid) then
        iic_$release(line, st);
end;
