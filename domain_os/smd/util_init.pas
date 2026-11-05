{ SMD_$UTIL_INIT - fill a drawing context for the current process.

  Image addresses:
    sau2  0x00E6DED4  SMD_$UTIL_INIT
    sau4  0x0F878634  SMD_$UTIL_INIT
    sau5  0x00E70310  SMD_$UTIL_INIT
    sau6  0x780776AE  SMD_$UTIL_INIT

  - ctx gets the unit's display memory base, register block and display
    record, and its status.
  - With `color_displays' (base/config.ins.pas) a color display (types
    3..6) gets smd_$not_on_color, after the fields are stored.

  Status stored: none.
}

procedure smd_$util_init(out ctx: smd_ws_ctx_t);
var
  unit: integer;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then
    ctx.status.all := smd_$illegal_caller
  else begin
    ctx.display_base := smd_$wired_data.unit[unit].display_base;
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
end;
