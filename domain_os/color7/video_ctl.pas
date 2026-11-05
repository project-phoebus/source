{ COLOR7_$VIDEO_CTL - turn the video on or off.

  Image addresses:
    sau7  0x3C484690  COLOR7_$VIDEO_CTL

  - The timing port's video register gets the configuration's value,
    without bit 3 to turn the video off; the descriptor is not read.

  Status stored: none.
}

procedure color7_$video_ctl(dcte: color7_$dcte_ptr_t; on: boolean);
  options(val_param);
var
  video: integer32;
begin
  if color7_static.config_13 then
    video := color7_$video_config_13
  else
    video := color7_$video_other;
  if not on then
    video := video & color7_$video_on_mask;
  color7_write_reg(color7_$port_timing, color7_$port_addr,
                   color7_$timing_video);
  color7_write_reg(color7_$port_timing, color7_$port_data_4, video);
end;
