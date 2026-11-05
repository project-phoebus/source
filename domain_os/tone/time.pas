{ TONE_$TIME - sound the speaker for a time.

  Image addresses:
    sau2  0x00E172FC  TONE_$TIME
    sau4  0x0F817CB4  TONE_$TIME
    sau7  0x3C418D38  TONE_$TIME
    sau9  0x3C419354  TONE_$TIME

  - The tone is on for the given time, a relative wait, with the process
    lock ml_$area_lock set.
  - With `kbd_tone' the keyboard's tone is sounded again for every
    75000 ticks of the time (each a wait of 74744 ticks), then for what
    is left of it, if anything.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tone_$time(duration: time_$clock_t);
var
%if kbd_tone %then
  unused_8: time_$clock_t;                { a stand-in: the code uses none of it }
  chunk: time_$clock_t;                   { one sounding's wait }
  limit: time_$clock_t;                   { what one sounding counts for }
  rest: time_$clock_t;                    { the time before the last subtraction }
%endif
  status: status_$t;
%if kbd_tone %then
  n: integer32;                           { the soundings of a full chunk }
%endif
begin
  proc1_$set_lock(ml_$area_lock);
%if kbd_tone %then
  limit.high := 1;
  limit.low := 16#24F8;
  chunk.high := 1;
  chunk.low := 16#23F8;
  n := 0;
  repeat
    rest := duration;
    if not sub48(duration, limit) then exit;
    n := n + 1;
  until false;
  for n := 1 to n do begin                { the bound is read once, before the loop }
    tone_$enable(true);
    time_$wait(time_$relative, chunk, status);
  end;
  if (rest.high <> 0) or else (rest.low <> 0) then begin
    tone_$enable(true);
    time_$wait(time_$relative, rest, status);
  end;
%else
  tone_$enable(true);
  time_$wait(time_$relative, duration, status);
%endif
  tone_$enable(false);
  proc1_$clr_lock(ml_$area_lock);
end;
