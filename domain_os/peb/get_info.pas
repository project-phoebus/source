{ PEB_$GET_INFO - report the board's state flags.

  Image addresses:
    sau2  0x00E709E8  PEB_$GET_INFO
    sau9  0x3C4770EA  PEB_$GET_INFO

  - A word set of five of PEB_$INFO's flags (WCS loaded, the 68881's
    save, the save pending, and two more), and PEB_$INFO's info byte.

  Status stored: none.
}

procedure peb_$get_info(out info: peb_$info_bits_t; out info_byte: char);
begin
  info := [];

  if peb_$info.wcs_loaded then
    info := info + [peb_$info_wcs_loaded];
  if peb_$info.m68881_save_flag then
    info := info + [peb_$info_m68881_mode];
  if peb_$info.savep_flag then
    info := info + [peb_$info_savep_flag];
  if peb_$info.flag_1d then
    info := info + [peb_$info_unknown_08];
  if peb_$info.flag_21 then
    info := info + [peb_$info_unknown_10];

  info_byte := peb_$info.info_byte;
end;
