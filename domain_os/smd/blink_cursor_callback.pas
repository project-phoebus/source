{ SMD_$BLINK_CURSOR_CALLBACK - the cursor-blink timer's routine.

  Image addresses:
    sau2  0x00E6FF56  SMD_$BLINK_CURSOR_CALLBACK
    sau4  0x0F87A862  SMD_$BLINK_CURSOR_CALLBACK
    sau5  0x00E72482  SMD_$BLINK_CURSOR_CALLBACK
    sau9  0x3C476354  SMD_$BLINK_CURSOR_CALLBACK

  - The timer is re-armed every time: 125000 ticks, or 250000 after a
    blink that left the cursor painted.  With `display_devices'
    (base/config.ins.pas) the default unit's device blinks the cursor.
  - The screen is blanked when blanking is enabled and the time-out has
    passed since the last activity (the first time only records it).
  - The touch-pad cursor is stopped at its time-out's second tick.

  Status stored: none.
}

{ TODO(pascal) 8 frame bytes of SMD_$BLINK_CURSOR_CALLBACK not accounted

  The image's frame is 0x10 bytes: interval at -0x8, status at -0x4, and
  -0x10..-0x9 that nothing addresses.  dpc's layout (`--dump-locals')
  gives the source above the two locals' 8 bytes.  The other 8 are not
  known (the other SMD frames with unexplained bytes: the README's TODO
  list). }

procedure smd_$blink_cursor_callback;
var
  status: status_$t;
  interval: integer32;
begin
  interval := 125000;

  { blink unless off or deferred }
%if display_devices %then
  with smd_$wired_data.unit[default_unit] do
    if smd_time_$com.blink_enable then begin
      if smd_time_$com.blink_defer = 0 then begin
        vector^.blink_cursor^(dcte, smd_time_$com,
                              smd_$display_com[default_unit]);
        if smd_time_$com.cursor_painted then
          interval := 250000;
      end;
      smd_time_$com.blink_defer := 0;
    end;
%else
  if smd_time_$com.blink_enable then begin
    if smd_time_$com.blink_defer = 0 then begin
      blink_func[default_unit]^;
      if smd_time_$com.cursor_painted then
        interval := 250000;
    end;
    smd_time_$com.blink_defer := 0;
  end;
%endif

  smd_$reschedule_blink_timer(interval);

  { blank the screen after the time-out }
  if not blank_flags.blank_pending and then
     blank_flags.blank_enabled and then
     (blank_timeout <> 0) and then
     (blank_timeout + blank_time < time_$clockh) then
    if blank_time <> 0 then begin
      asid_to_unit[proc1_$as_id] := default_unit;
      smd_$video_ctl(false, status);
      blank_flags.blank_pending := true;
    end
    else
      blank_time := time_$clockh;

  { the touch-pad cursor's time-out }
  if tp_cursor_timeout >= 0 then begin
    tp_cursor_timeout := tp_cursor_timeout + 1;
    if tp_cursor_timeout >= 2 then
      smd_$stop_tp_cursor(default_unit);
  end;
end;
