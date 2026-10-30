{ peb_$read_wcs - read one entry of the board's writable control store.

  Image addresses:
    sau2  0x00E31E4E  peb_$read_wcs
    sau5  0x00E333A6  peb_$read_wcs

  - The WCS address's bits 7 and up select the WCS page (the control
    word's page field, shadow and board); its low 7 bits one of the
    page's 128 entries, whose three fields are read.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure peb_$read_wcs(wcs_addr: integer; out data: peb_$wcs_entry_t);
  internal;
var
  ctl: peb_$ctl_bits_t;
begin
  { the WCS page }
  ctl := peb_$info.ctl_shadow;
  ctl.wcs_page := rshft(wcs_addr, 7);
  peb_$info.ctl_shadow := ctl;
  peb_ctl.ctl := ctl;

  { the entry }
  data.word0 := peb_ctl.wcs[wcs_addr & 16#7F].word0;
  data.word1 := peb_ctl.wcs[wcs_addr & 16#7F].word1;
  data.word2 := peb_ctl.wcs[wcs_addr & 16#7F].word2;
end;
