{ SMD_$UNBLANK - note the activity time, and turn the video back on if the
  screen was blanked.

  Image addresses:
    sau2  0x00E6EFB4  SMD_$UNBLANK
    sau5  0x00E71364  SMD_$UNBLANK
    sau9  0x3C4757B4  SMD_$UNBLANK

  - The blink callback blanks the screen when the activity time gets too
    old.
  - Unblanking makes the process's display unit the default again;
    SMD_$VIDEO_CTL's status is ignored.

  Status stored: none.
}

procedure smd_$unblank;
var
  status: status_$t;
begin
  blank_time := time_$clockh;
  if blank_flags.blank_pending then begin
    asid_to_unit[proc1_$as_id] := default_unit;
    smd_$video_ctl(true, status);
  end;
end;
