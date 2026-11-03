{ SMD_$FREE_ASID - release an address space's hold on the displays.

  Image addresses:
    sau2  0x00E75250  SMD_$FREE_ASID
    sau3  0x00E767F0  SMD_$FREE_ASID
    sau4  0x0F882A0C  SMD_$FREE_ASID
    sau5  0x00E7C3F0  SMD_$FREE_ASID
    sau9  0x3C47CDCC  SMD_$FREE_ASID

  - For each display unit (1 here, 1 and 2 with `two_display_units',
    base/config.ins.pas): a display the address space borrowed is
    returned, and the display memory unmapped.
  - A color display's driver dissociates it (COLOR_$DISSOC with
    `color_board', COLOR2_$DISSOC with `gpu_driver').
  - With `display_devices' each of the eight units' mapping of the
    address space is unmapped through SMD_$UNMAP_DISPLAY_MEMORY, and a
    unit's device dissociates the process and, for a process other than
    0, closes it.
  - In PROC2_DELETE_PRO, its data section DATA$: the routine has no
    static data.

  - Without `display_driver' (no display: the SAU3) an empty procedure.
  Status stored: none.
}
{ TODO(pascal) SMD_$FREE_ASID's frame: 8 bytes with no object

  The image's frame is 0x10 bytes; status and the temporary of the
  by-address unit are the only slots the code addresses.  dpc's layout
  of the routine is 12 bytes, u in the second slot; 4 bytes more in the
  image, and 8 the code never addresses.  What they held (a `with' slot,
  the stepped pointer's home) is not known.  Not settled. }

[section(proc2_delete_pro, data$)]
procedure smd_$free_asid(asid: integer);
  options(val_param);
%if display_driver %then
var
  status: status_$t;
  u: integer;
begin
  for u := 1 to smd_unit_count do
    with smd_$wired_data.unit[u]
%if color_board or gpu_driver %then
         , hw^
%endif
         do begin
      if borrowed_asid = asid then
        smd_$return_display(u, status);
%if display_devices %then
      { the process's mapping, its association and its hold on the
        device }
      if mapped_addresses[asid] <> nil then
        smd_$unmap_display_memory(u, 16#40000, 0, mapped_addresses[asid],
                                  status);
      if vector <> nil then begin
        vector^.dissoc^(dcte, status);
        if asid <> 0 then
          vector^.close^(dcte, asid);
      end;
%else
      smd_$unmap_display_u(status);
%endif
%if color_board %then
      if display_type in [smd_$color_display, smd_$800_color] then
        color_$dissoc;
%endif
%if gpu_driver %then
      if display_type in [smd_$color2_display, smd_$color3_display] then
        color2_$dissoc;
%endif
    end;
  asid_to_unit[asid] := 0;
end;
%else
begin
end;
%endif
