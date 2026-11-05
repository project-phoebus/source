{ COLOR2_$VIDEO_CTL - turn the graphics board's color display on or off.

  Image addresses:
    sau5  0x00E1E6C0  COLOR2_$VIDEO_CTL
    sau6  0x7801FC38  COLOR2_$VIDEO_CTL

  - In WIRED_PROC: SMD calls it at interrupt level.  The DN580's display
    takes member 3 of the board's control word; the DN570's bit 3 of
    COLOR3_$CR_CONTENTS, then written to the board at +0x7020.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure color2_$video_ctl(in flags: boolean);
var
  on: boolean;
begin
  on := flags;
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    if on then
      kolor_ctl.ctl := kolor_ctl.ctl + [3]
    else
      kolor_ctl.ctl := kolor_ctl.ctl - [3];
  end
  else if smd_$graphic_device_id = smd_gdev_color3 then begin
    if on then
      color3_$cr_contents := color3_$cr_contents ! 16#8
    else
      color3_$cr_contents := color3_$cr_contents & 16#FFF7;
    kolor_ctl.cr := color3_$cr_contents;
  end;
end;
