{ SMD_$SET_KBD_TYPE - set the keyboard type, through KBD.

  Image addresses:
    sau2  0x00E6E1AE  SMD_$SET_KBD_TYPE
    sau5  0x00E70618  SMD_$SET_KBD_TYPE
    sau9  0x3C474AF6  SMD_$SET_KBD_TYPE

  - For line 0.

  Status stored:
    kbd_$set_kbd_type's status: always
}

procedure smd_$set_kbd_type(in kbd_type: univ smd_$string_t;
                            in length: pinteger;
                            out status: status_$t);
begin
  kbd_$set_kbd_type(0, kbd_type, length, status);
end;
