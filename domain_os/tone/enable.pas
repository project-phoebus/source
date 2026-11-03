{ TONE_$ENABLE - turn the speaker tone on or off.

  Image addresses:
    sau2  0x00E1ACE8  TONE_$ENABLE
    sau3  0x00E1A33A  TONE_$ENABLE
    sau9  0x3C41D862  TONE_$ENABLE

  - A fragment of the OS_TERM_INIT module, not of TONE: the map has it
    last in that module's WIRED_PROC segment, and the speaker's SIO2681
    channel record is that module's (term/os_term_init.pas).
  - With `kbd_tone' the keyboard sounds the tone: one of its two tone
    commands goes to the console keyboard through KBD_$PUT.
  - The callee's status is dropped.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tone_$enable(in enable: boolean);
var
  status: status_$t;
begin
%if kbd_tone %then
  if enable then
    kbd_$put(0, 0, tone_$on_string, 3, status)
  else
    kbd_$put(0, 0, tone_$off_string, 3, status);
%else
  sio2681_$tone(addr(tone_$channel), enable, status);
%endif
end;
