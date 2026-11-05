{ SMD_$WS_INIT - fill a string-drawing context for the current process.

  Image addresses:
    sau2  0x00E6DE58  SMD_$WS_INIT
    sau4  0x0F87859C  SMD_$WS_INIT
    sau5  0x00E70278  SMD_$WS_INIT
    sau6  0x78077616  SMD_$WS_INIT

  - ctx's font index, the caller's, picks the font; ctx gets its pointer
    and hidden-memory position, the unit's register block and display
    record, and a status.
  - With `color_displays' (base/config.ins.pas) a color display (types
    3..6) gets smd_$not_on_color, after the fields are stored.

  Status stored: none.
}

procedure smd_$ws_init(in out ctx: smd_ws_ctx_t);
var
  unit: integer;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    ctx.status.all := smd_$illegal_caller;
    return;
  end;

  with smd_$wired_data.unit[unit].font_table^[ctx.font_index] do begin
    ctx.font_ptr := font_va;
    if ctx.font_ptr = nil then begin
      ctx.status.all := smd_$font_not_loaded;
      return;
    end;
    ctx.font_hdm_pos := hdm_pos;
  end;
  ctx.ctrl_regs := smd_$wired_data.unit[unit].ctrl_regs;
  ctx.hw := smd_$wired_data.unit[unit].hw;
%if color_displays %then
  if ctx.hw^.display_type in
     [smd_$color_display..smd_$color3_display] then
    ctx.status.all := smd_$not_on_color
  else
%endif
  ctx.status.all := status_$ok;
end;
