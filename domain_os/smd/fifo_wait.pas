{ SMD_$FIFO_WAIT - wait for every unit's display FIFO.

  Image addresses:
    sau9  0x3C4202D6  SMD_$FIFO_WAIT

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$fifo_wait;
var
  u: integer;
begin
  for u := 1 to smd_$wired_data.unit_count do
    with smd_$wired_data.unit[u] do
      vector^.fifo_wait^(dcte);
end;
