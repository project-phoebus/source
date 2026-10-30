{ SMD_$MAP_DISPLAY_U - map the display memory into the caller's space.

  Image addresses:
    sau2  0x00E6F8D0  SMD_$MAP_DISPLAY_U
    sau5  0x00E71D7A  SMD_$MAP_DISPLAY_U
    sau9  0x3C475F64  SMD_$MAP_DISPLAY_U

  - A display already mapped for the process is returned as it is.
  - With `display_devices' (base/config.ins.pas) the unit's device maps
    the display.
  - The heading is Apollo's (smdu.ins.pas).

  Status stored:
    status_$ok: the display was mapped already
    mst_$map's or the device's status: status_$ok, or its failure with the fail bit set
    smd_$illegal_caller: the process has no display unit
}

procedure smd_$map_display_u(
  out display_address: smd_$display_memory_ptr_t;
  out status: status_$t);
var
  map_info: integer32;
  unit: integer;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  with smd_$wired_data.unit[unit] do begin
    display_address := mapped_addresses[proc1_$as_id];
    if display_address = nil then begin
%if display_devices %then
      vector^.map^(dcte, 0, 0, display_address, status);
%else
      display_address := mst_$map(display_uid, 0,
                                  display_map_length[ord(hw^.display_type)],
                                  6, 0, false, map_info,
                                  status);
%endif
      if status.all <> status_$ok then
        status.fail := true;
      mapped_addresses[proc1_$as_id] := display_address;
    end
    else
      status.all := status_$ok;
  end;
end;
