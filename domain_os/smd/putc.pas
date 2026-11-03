{ SMD_$PUTC - put a character on the display.

  Image addresses:
    sau2  0x00E1D89C  SMD_$PUTC
    sau4  0x0F81EC5A  SMD_$PUTC
    sau5  0x00E1E65C  SMD_$PUTC
    sau9  0x3C4201DC  SMD_$PUTC

  - An empty procedure, but with `display_devices' (base/config.ins.pas),
    where every unit's device gets the longword and the character.

  Status stored: none.
}

%if display_devices %then
[section(wired_proc, wired_data)]
procedure smd_$putc(var arg_1: integer32; in c: integer);
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.putc^(dcte, arg_1, c);
end;
%else
[section(wired_proc, wired_data)]
procedure smd_$putc(in c: integer);
begin
end;
%endif
