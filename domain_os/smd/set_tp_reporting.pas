{ SMD_$SET_TP_REPORTING - set the touch pad's reporting mode.

  Image addresses:
    sau2  0x00E6E4B0  SMD_$SET_TP_REPORTING
    sau4  0x0F878C46  SMD_$SET_TP_REPORTING
    sau5  0x00E70932  SMD_$SET_TP_REPORTING
    sau9  0x3C474EB8  SMD_$SET_TP_REPORTING

  - SMD_$LOC_EVENT tests the mode.

  Status stored:
    status_$ok: always
}

procedure smd_$set_tp_reporting(mode: integer; out status: status_$t);
begin
  tp_reporting := mode;
  status.all := status_$ok;
end;
