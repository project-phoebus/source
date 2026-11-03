{ dtty_$get_disp_type - the display type DTTY_$INIT found.

  Image addresses:
    sau2  0x00E1D588  dtty_$get_disp_type
    sau4  0x0F81E78C  dtty_$get_disp_type
    sau9  0x3C41FF78  dtty_$get_disp_type

  - With `smd_display_memory' DTTY_$INIT keeps no display type, and
    this is an empty procedure.
  - With `dtty_color_board' it waits, on a color display, until the
    color board is idle (status members 13 and 15 clear), and returns no
    value.

  Status stored: none.
}

%if smd_display_memory %then
procedure dtty_$get_disp_type; internal;
begin
end;
%elseif dtty_color_board %then
procedure dtty_$get_disp_type; internal;
begin
  case dtty_$disp_type of
    smd_$bw_15p, smd_$bw_19l: { empty };
    smd_$color_display, smd_$800_color:
      with color_sup do begin
        while 13 in status do { empty };
        while 15 in status do { empty };
      end;
  end;
end;
%else
function dtty_$get_disp_type: smd_$display_type_t; internal;
begin
  dtty_$get_disp_type := dtty_$disp_type;
end;
%endif
