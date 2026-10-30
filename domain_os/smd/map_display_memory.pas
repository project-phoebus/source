{ SMD_$MAP_DISPLAY_MEMORY - map display memory.

  Image addresses:
    sau2  0x00E700AA  SMD_$MAP_DISPLAY_MEMORY
    sau5  0x00E725D6  SMD_$MAP_DISPLAY_MEMORY
    sau9  0x3C476510  SMD_$MAP_DISPLAY_MEMORY

  - Not implemented; the first four parameters are not read.  With
    `display_devices' (base/config.ins.pas) the unit's device maps the
    display memory into the process, once: a mapping the process has is
    returned as it is.

  Status stored:
    smd_$not_implemented: always (without `display_devices')
    status_$ok: the process had the memory mapped already
    the device's map's status: the device mapped it
    smd_$illegal_unit: the unit is not valid
}

%if display_devices %then
procedure smd_$map_display_memory(in unit: integer; in arg_2: integer32;
                                  in arg_3: integer32; out va: univ_ptr;
                                  out status: status_$t);
var
  mapped: univ_ptr;
begin
  if smd_$validate_unit(unit) then
    with smd_$wired_data.unit[unit] do begin
      mapped := mapped_addresses[proc1_$as_id];
      if mapped <> nil then begin
        va := mapped;
        status.all := status_$ok;
      end
      else begin
        vector^.map^(dcte, arg_2, arg_3, va, status);
        if status.all = status_$ok then
          mapped_addresses[proc1_$as_id] := va;
      end;
    end
  else
    status.all := smd_$illegal_unit;
end;
%else
procedure smd_$map_display_memory(in param1: integer32;
                                  in param2: integer32;
                                  in param3: integer32;
                                  in param4: integer32;
                                  out status: status_$t);
begin
  status.all := smd_$not_implemented;
end;
%endif
