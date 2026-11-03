{ SMD_$GET_IDM_EVENT - take the next event off the display's ring in the
  input device manager's form.

  Image addresses:
    sau2  0x00E6EE28  SMD_$GET_IDM_EVENT
    sau4  0x0F87956C  SMD_$GET_IDM_EVENT
    sau5  0x00E711D8  SMD_$GET_IDM_EVENT
    sau9  0x3C475632  SMD_$GET_IDM_EVENT

  - The record's last word: a button event's buttons (remembered), a
    keystroke's character and modifier, or for a pointer-up event the
    remembered buttons, the type becoming button-down.
  - Type 4, and any type outside 1..5, leaves the word as it was.

  Status stored:
    smd_$get_unit_event's status: always
}

procedure smd_$get_idm_event(out event_type: integer;
                             out idm_data: smd_idm_event_t;
                             out status: status_$t);
var
  ue: smd_unit_event_t;
begin
  smd_$get_unit_event(event_type, ue, status);
  idm_data.hdr := ue.hdr;
  case event_type of
    smd_$evtype_pointer_up: begin
      event_type := smd_$evtype_button_down;
      idm_data.data := last_idm_button;
    end;
    smd_$evtype_button_down, smd_$evtype_button_up: begin
      last_idm_button := ue.button_or_char;
      idm_data.data := ue.button_or_char;
    end;
    smd_$evtype_keystroke: begin
      idm_data.char_code := ue.char_code;
      idm_data.modifier := ue.modifier;
    end;
  end;
end;
