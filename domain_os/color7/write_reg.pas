{ color7_write_reg - write a register of a color map port.

  Image addresses:
    sau7  0x3C48CE32  color7_write_reg (module-local)

  - reg is the port, offset the register's offset in it.  The ports from
    color7_$port_wait_first to color7_$port_wait_last are written once
    the control register's busy bit is clear, polled up to 10000 times;
    the write is made when the polls run out too.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_write_reg(reg: integer32; offset: integer32;
                           value: integer32);
var
  i: integer32;
begin
  if (reg >= color7_$port_wait_first) and then
     (reg <= color7_$port_wait_last) then begin
    i := 0;
    while (color7_$ctl_port_busy in
           color7_$ctl_reg_ptr_t(integer32(color7_static.regs) +
                                 color7_$ctl_offset)^.ctl.bits) and then
          (i < color7_$port_polls) do
      i := i + 1;
  end;
  color7_$ports_ptr_t(integer32(color7_static.regs) +
                      color7_$ports_offset)^.port[(reg + offset) div 4] :=
    value;
end;
