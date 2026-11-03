{ SMD_$LOAD_FONT - load a font into hidden display memory.

  Image addresses:
    sau2  0x00E6DC1C  SMD_$LOAD_FONT
    sau4  0x0F878332  SMD_$LOAD_FONT
    sau5  0x00E70016  SMD_$LOAD_FONT

  - The result is the font's slot, 1..8: the first free one, its hidden
    display memory allocated and the font copied there with the display
    acquired.
  - The result is set only on success.

  Status stored:
    status_$ok: the font was loaded (SMD_$ALLOC_HDM's)
    smd_$illegal_caller: the process has no display unit
    smd_$unsupported_font_ver: no font, or a version other than 1 and 3
    smd_$font_table_full: no slot is free
    smd_$alloc_hdm's status: no hidden display memory
}

{ TODO(pascal) frame of SMD_$LOAD_FONT not accounted

  The frame is 0x20 bytes; the code addresses only need, in the second
  word slot.  The locals (unit, i, need 2 bytes each, fonts 4) take 12
  bytes; with need there the 2 bytes above it hold unit or i.  The other
  20 bytes are not explained by the locals; no `with' slot is read (the
  element address and table_ptr^ live in registers).  The declaration
  order is chosen to fit the one address the image shows. }

function smd_$load_font(in table_ptr: univ smd_$font_table_ptr_t;
                        out status: status_$t): pinteger;
var
  unit: integer;
  i: integer;
  need: integer;
  fonts: smd_unit_fonts_ptr_t;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;

  if table_ptr = nil then begin
    status.all := smd_$unsupported_font_ver;
    return;
  end;

  fonts := smd_$wired_data.unit[unit].font_table;
  if (table_ptr^.version <> 1) and
     (table_ptr^.version <> 3) then begin
    status.all := smd_$unsupported_font_ver;
    return;
  end;

  { the first free slot }
  i := 1;
  while i <= 8 do begin
    if fonts^[i].font_va = nil then
      exit;
    i := i + 1;
  end;
  if i > 8 then begin
    status.all := smd_$font_table_full;
    return;
  end;

  { the hidden memory the font needs }
  if table_ptr^.version = 1 then
    need := table_ptr^.raster_lines
  else
    need := smd_font_v3_ptr_t(table_ptr)^.hdm_size;

  smd_$alloc_hdm(need, fonts^[i].hdm_pos, status);
  if status.all <> status_$ok then
    return;

  fonts^[i].font_va := table_ptr;
  discard(smd_$acq_display(1));
  smd_$copy_font_to_hdm(smd_$wired_data.unit[unit].display_base,
                        table_ptr, fonts^[i].hdm_pos);
  smd_$rel_display;

  smd_$load_font := i;
end;
