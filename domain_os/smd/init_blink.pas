{ SMD_$INIT_BLINK - set up the cursor blink.

  Image addresses:
    sau2  0x00E34EB2  SMD_$INIT_BLINK
    sau4  0x0F8382BC  SMD_$INIT_BLINK
    sau5  0x00E37268  SMD_$INIT_BLINK
    sau6  0x7803E8A0  SMD_$INIT_BLINK
    sau7  0x3C43E634  SMD_$INIT_BLINK
    sau9  0x3C43B604  SMD_$INIT_BLINK

  - The first blink callback is queued 125000 ticks from now, only when
    the current unit has a display.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure smd_$init_blink;
var
  has_display: boolean;
begin
  { the blink's common block }
  smd_time_$com.blink_enable := false;
  smd_time_$com.cursor_painted := true;
  smd_time_$com.blink_defer := 0;

  { the first blink, for a unit with a display }
  has_display := smd_$inq_disp_type(default_unit) <> smd_$none;
  if has_display then
    smd_$reschedule_blink_timer(125000);
end;
