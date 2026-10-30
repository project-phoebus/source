{ COLOR2_$BUSY_WAIT - wait for the graphics board to be idle.

  Image addresses:
    sau5  0x00E73460  COLOR2_$BUSY_WAIT

  - The DN580's display: until its status has member 14 (done) and not
    member 15 (busy), clearing bit 15 of the word at +0x7008 whenever
    member 7 is set.
  - The DN570's: unless its status had member 13 at the start, member
    10 or more than 65535 rounds resets the board and ends the wait;
    else the wait ends at member 14 with the low four bits set.

  Status stored:
    status_$ok: always
}

procedure color2_$busy_wait(out status: status_$t);
label
  done;
var
  count: linteger;
  field: set of 0..15;
  s: set of 0..15;
  ready_at_start: boolean;
  w: set of 0..15;
begin
  count := 0;
  status.all := count;
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    field := kolor_ctl.status * [1, 2];
    with kolor_ctl do
      repeat
        s := status;
        if 7 in s then
          reg_7008 := reg_7008 - [15];
      until (14 in s) and then not (15 in s);
  end
  else if smd_$graphic_device_id = smd_gdev_color3 then begin
    if 13 in kolor_ctl.status_7030 then
      ready_at_start := true
    else
      ready_at_start := false;
    with kolor_ctl do
      repeat
        s := status_7030;
        count := count + 1;
        if not ready_at_start then
          if (10 in s) or else (count > 65535) then begin
            color3_$cr_contents := color3_$cr_contents ! 16#1;
            cr := color3_$cr_contents;
            repeat
              w := status_7030;
            until not (11 in w);
            color3_$cr_contents := color3_$cr_contents & 16#FFFE;
            cr := color3_$cr_contents;
            repeat
            until 11 in status_7030;
            goto done;
          end;
      until (14 in s) and then (s * [0, 1, 2, 3] = [0, 1, 2, 3]);
  end;
done:
end;
