{ KBD_$CRASH_INIT - prepare the keyboard for the crash console.

  Image addresses:
    sau2  0x00E1CE94  KBD_$CRASH_INIT
    sau6  0x7801EF66  KBD_$CRASH_INIT
    sau7  0x3C421252  KBD_$CRASH_INIT
    sau9  0x3C41FBA2  KBD_$CRASH_INIT

  - An empty procedure but with `kbd_commands': the descriptor KBD_$INIT
    last set up, if any, goes back to state 0 and keyboard type 0, and
    KBD_$GET_CHAR_AND_MODE's command counts as not sent.

  Status stored: none.
}

procedure kbd_$crash_init;
begin
%if kbd_commands %then
  if kbd_$console_desc <> nil then
    with kbd_$console_desc^ do begin
      state := 0;
      kbd_type_idx := 0;
      flags := flags - [kbd_$flag_cmd_sent];
    end;
%endif
end;
