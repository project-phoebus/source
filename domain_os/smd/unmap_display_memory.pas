{ SMD_$UNMAP_DISPLAY_MEMORY - unmap display memory.

  Image addresses:
    sau2  0x00E700C8  SMD_$UNMAP_DISPLAY_MEMORY
    sau4  0x0F87A9D4  SMD_$UNMAP_DISPLAY_MEMORY
    sau5  0x00E725F4  SMD_$UNMAP_DISPLAY_MEMORY
    sau9  0x3C4765AA  SMD_$UNMAP_DISPLAY_MEMORY

  - Not implemented; the first four parameters are not read.

  Status stored:
    smd_$not_implemented: always
}

%if display_devices %then
procedure smd_$unmap_display_memory(in unit: integer; in arg_2: integer32;
                                    in arg_3: integer32; in va: univ_ptr;
                                    out status: status_$t);
begin
  if smd_$validate_unit(unit) then
    with smd_$wired_data.unit[unit] do begin
      vector^.unmap^(dcte, arg_2, arg_3, va, status);
      mapped_addresses[proc1_$as_id] := nil;
    end
  else
    status.all := smd_$illegal_unit;
end;
%else
procedure smd_$unmap_display_memory(in param1: integer32;
                                    in param2: integer32;
                                    in param3: integer32;
                                    in param4: integer32;
                                    out status: status_$t);
begin
  status.all := smd_$not_implemented;
end;
%endif
