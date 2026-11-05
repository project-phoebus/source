{ SMD_$COND_INPUT_U - return a typed character if there is one.

  Image addresses:
    sau2  0x00E6FA14  SMD_$COND_INPUT_U
    sau4  0x0F87A2D4  SMD_$COND_INPUT_U
    sau5  0x00E71ECA  SMD_$COND_INPUT_U
    sau6  0x780791DE  SMD_$COND_INPUT_U

  - Input events are taken until there are none or a call fails; a
    keystroke with modifier 0 or 15 is returned in ch, the result true.
  - The first keystroke with modifier 1 sets line 0's keyboard mode to 0
    (TERM_$CONTROL option 36), once.
  - The heading is Apollo's (smdu.ins.pas).

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of SMD_$COND_INPUT_U not accounted

  The image's frame is 28 bytes: event_data at -0x10 (12 bytes), the
  status at -0x14, event_type at -0x16.  dpc's layout (the locals in the
  order below) gives 24 bytes with each of them 4 higher, event_data at
  -0xC, the status at -0x10, event_type at -0x12 (then result and
  ctrl_sent, which the image keeps in registers).  So the image has 4
  bytes above event_data, -0x4..-0x1, that nothing addresses. }

function smd_$cond_input_u(out ch: char): boolean;
var
  event_data: smd_idm_event_t;
  status: status_$t;
  event_type: integer;
  result: boolean;
  ctrl_sent: boolean;
begin
  result := false;
  if asid_to_unit[proc1_$as_id] <> 0 then begin
    ctrl_sent := false;
    repeat
      smd_$get_idm_event(event_type, event_data, status);
      if status.all <> status_$ok then
        exit;
      if event_type = smd_$evtype_keystroke then begin
        if (event_data.modifier = chr(0))
           or else (event_data.modifier = chr(15)) then begin
          ch := event_data.char_code;
          result := true;
          exit;
        end
        else if not ctrl_sent
                and then (event_data.modifier = chr(1)) then begin
          term_$control(0, 36, 0, status);
          ctrl_sent := true;
        end;
      end;
    until event_type = smd_$evtype_none;
  end;
  smd_$cond_input_u := result;
end;
