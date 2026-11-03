{ SMD_$COPY_FONT_TO_MD_HDM - copy the boot font into the monochrome
  display's hidden memory.

  Image addresses:
    sau2  0x00E1D750  SMD_$COPY_FONT_TO_MD_HDM
    sau4  0x0F81EA70  SMD_$COPY_FONT_TO_MD_HDM
    sau5  0x00E1E38C  SMD_$COPY_FONT_TO_MD_HDM
    sau9  0x3C42015E  SMD_$COPY_FONT_TO_MD_HDM

  - With the display acquired, 39 rows of 14 words go to word column 50
    beside the visible area: from line 1 on a type 1 display, from line
    984 on a type 2; other types copy nothing.
  - With `color_board' or `gpu_driver' (base/config.ins.pas) the color
    types copy too, after waiting for their boards.
  - With `display_devices' the unit's device copies the font.
  - The result is always 0.

  Status stored:
    status_$ok: the font was copied, or the type copies nothing
    the device's copy_font's status: with `display_devices'
    smd_$unsupported_font_ver: font_ptr is nil
    smd_$illegal_caller: the process has no display unit
}

{ TODO(pascal) frame of SMD_$COPY_FONT_TO_MD_HDM not accounted

  The image's frame is 0x2C bytes: pos at -0xC, the outer `for' count at
  -0x22 and the two widened lines at -0x28 and -0x2C are the only bytes
  the code addresses.  With the declared locals (unit 2, font 4, pos 4,
  i 2, j 2, the result 2) and the `with' slot (4) the declared part is
  20 bytes; where the compiler places the count and the widened line
  copies (one per loop) is not a known form, and pos at -0xC rather than
  nearer the top is not explained.  dpc's frame is 24 bytes. }

[section(wired_proc, wired_data)]
function smd_$copy_font_to_md_hdm(var font_ptr: univ_ptr;
                                  out status: status_$t): integer;
type
  smd_md_font_t = array[0..38] of array[0..13] of pinteger;
  smd_md_font_ptr_t = ^smd_md_font_t;
var
  unit: integer;
  font: smd_md_font_ptr_t;
  pos: smd_$pos_t;
  i: integer;
  j: integer;
%if color_board %then
  csup: smd_color_sup_ptr_t;
%endif
%if color_board or gpu_driver %then
  wait_status: status_$t;
%endif
begin
  status.all := status_$ok;

  { no font }
  if font_ptr = nil then
    status.all := smd_$unsupported_font_ver
  else begin
    { the calling process's display unit }
    unit := asid_to_unit[proc1_$as_id];
    if unit = 0 then
      status.all := smd_$illegal_caller
    else begin
      discard(smd_$acq_display(1));

      { the copy, for the two monochrome types }
      with smd_$wired_data.unit[unit] do begin
%if display_devices %then
        discard(vector^.copy_font^(dcte, font_ptr, status));
%else
        font := font_ptr;
        case hw^.display_type of
          smd_$bw_15p: begin
            pos.line := 1;
            pos.column := 50;
            for i := 0 to 38 do
              for j := 0 to 13 do
                display_base^[pos.line + i, pos.column + j] :=
                  font^[i, j];
          end;
          smd_$bw_19l: begin
            pos.line := 984;
            pos.column := 50;
            for i := 0 to 38 do
              for j := 0 to 13 do
                display_base^[pos.line + i, pos.column + j] :=
                  font^[i, j];
          end;
%if color_board %then
          smd_$color_display, smd_$800_color: begin
            pos.line := 1;
            pos.column := 50;
            csup := addr(color_sup);
            color_$inq_done_wait(wait_status);
            csup^.field_90 := 7;
            for i := 0 to 38 do
              for j := 0 to 13 do
                display_base^[pos.line + i, pos.column + j] :=
                  font^[i, j];
            csup^.field_90 := 0;
          end;
%endif
%if gpu_driver %then
          smd_$color2_display: begin
            pos.line := 1;
            pos.column := 80;
            color2_$busy_wait(wait_status);
            for i := 0 to 38 do
              for j := 0 to 13 do
                smd_wide_memory_ptr_t(display_base)^
                  [pos.line + i, pos.column + j] := font^[i, j];
          end;
          smd_$color3_display: begin
            pos.line := 984;
            pos.column := 50;
            color2_$busy_wait(wait_status);
            for i := 0 to 38 do
              for j := 0 to 13 do
                display_base^[pos.line + i, pos.column + j] :=
                  font^[i, j];
          end;
%endif
        end;
%endif
      end;

      smd_$rel_display;
    end;
  end;

  smd_$copy_font_to_md_hdm := 0;
end;
