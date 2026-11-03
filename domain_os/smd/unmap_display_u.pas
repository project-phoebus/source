{ SMD_$UNMAP_DISPLAY_U - unmap the display memory from the caller's space.

  Image addresses:
    sau2  0x00E6F97C  SMD_$UNMAP_DISPLAY_U
    sau4  0x0F87A236  SMD_$UNMAP_DISPLAY_U
    sau5  0x00E71E2C  SMD_$UNMAP_DISPLAY_U
    sau9  0x3C475FEC  SMD_$UNMAP_DISPLAY_U

  - The process's address is forgotten whatever MST_$UNMAP answers
    (with `display_devices', base/config.ins.pas, the unit's device
    unmaps it).

  Status stored:
    mst_$unmap's or the device's status: status_$ok, or its failure with the fail bit set
    smd_$illegal_caller: the process has no display unit
    smd_$not_mapped: the process has not mapped the display
}

procedure smd_$unmap_display_u(out status: status_$t);
var
  va: univ_ptr;
  unit: integer;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  with smd_$wired_data.unit[unit] do begin
    va := mapped_addresses[proc1_$as_id];
    if va = nil then begin
      status.all := smd_$not_mapped;
      return;
    end;
%if display_devices %then
    vector^.unmap^(dcte, 0, 0, va, status);
%else
    mst_$unmap(display_uid, integer32(va),
               display_map_length[ord(hw^.display_type)],
               status);
%endif
    mapped_addresses[proc1_$as_id] := nil;
    if status.all <> status_$ok then
      status.fail := true;
  end;
end;
