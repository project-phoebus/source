{ WIN_$SPIN_DOWN - stop the drive's spindle.

  Image addresses:
    sau2  0x00E19BC0  WIN_$SPIN_DOWN
    sau5  0x00E1A0A4  WIN_$SPIN_DOWN

  - The ANSI form issues SPIN CONTROL (16#55) with 0; the result is 20
    when it succeeded, else 0.
  - The descriptor-list form restores drive 0 unless WIN_$DT is set; the
    result is 3.

  Status stored: none.
}

%if win_descriptor_ctlr %then
function win_$spin_down(in unit: pinteger): integer;
begin
  if win_$dt = 0 then
    discard(restore(unit, 0));
  win_$spin_down := 3;
end;
%else

function win_$spin_down(in unit: pinteger): integer;
var
  status: integer32;
  out_byte: win_$byte_t;
begin
  status := win_$ansi_command(unit, 16#55, chr(0), out_byte);
  if status = status_$ok then
    win_$spin_down := 16#14
  else
    win_$spin_down := 0;
end;
%endif
