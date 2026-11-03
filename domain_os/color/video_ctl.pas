{ COLOR_$VIDEO_CTL - turn the color display on or off.

  Image addresses:
    sau4  0x0F81EC98  COLOR_$VIDEO_CTL
    sau5  0x00E1E69C  COLOR_$VIDEO_CTL

  - In WIRED_PROC: SMD calls it at interrupt level.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure color_$video_ctl(in flags: boolean);
var
  on: boolean;
begin
  on := flags;
  if on then
    color_sup.command := color_cmd_display_on
  else
    color_sup.command := color_cmd_display_off;
end;
