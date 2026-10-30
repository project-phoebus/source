{ dtty_$get_disp_type - the display type DTTY_$INIT found.

  Image addresses:
    sau2  0x00E1D588  dtty_$get_disp_type
    sau9  0x3C41FF78  dtty_$get_disp_type

  - With `smd_display_memory' DTTY_$INIT keeps no display type, and
    this is an empty procedure.

  Status stored: none.
}

%if smd_display_memory %then
procedure dtty_$get_disp_type; internal;
begin
end;
%else
function dtty_$get_disp_type: smd_$display_type_t; internal;
begin
  dtty_$get_disp_type := dtty_$disp_type;
end;
%endif
