{ SMD_$INIT_STATE - put the caller's display back in its initial state.

  Image addresses:
    sau2  0x00E6F818  SMD_$INIT_STATE
    sau5  0x00E71C90  SMD_$INIT_STATE
    sau9  0x3C475EAA  SMD_$INIT_STATE

  - The display is reset; the video is not touched (full false).

  Status stored:
    smd_$init_display_state's status: always
}

procedure smd_$init_state(out status: status_$t);
begin
  smd_$init_display_state(false, status);
end;
