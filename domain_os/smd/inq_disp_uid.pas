{ SMD_$INQ_DISP_UID - inquire a display unit's UID.

  Image addresses:
    sau2  0x00E70062  SMD_$INQ_DISP_UID
    sau5  0x00E7258E  SMD_$INQ_DISP_UID
    sau9  0x3C4764AC  SMD_$INQ_DISP_UID

  - The UID is UID_$NIL, whatever the unit; with `display_devices'
    (base/config.ins.pas) a valid unit's is its device's hardware UID.

  Status stored:
    status_$ok: the unit is valid
    smd_$illegal_unit: the unit is not valid
}

procedure smd_$inq_disp_uid(in unit: integer;
                            out uid: uid_$t;
                            out status: status_$t);
begin
  uid := uid_$nil;
  if not smd_$validate_unit(unit) then
    status.all := smd_$illegal_unit
  else begin
%if display_devices %then
    uid := smd_$wired_data.unit[unit].vector^.hw_uid;
%endif
    status.all := status_$ok;
  end;
end;
