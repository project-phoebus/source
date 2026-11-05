{ SMD_$DRAW_BOX - draw a box on the current process's display.

  Image addresses:
    sau2  0x00E6DF2A  SMD_$DRAW_BOX
    sau4  0x0F8786AA  SMD_$DRAW_BOX
    sau5  0x00E70386  SMD_$DRAW_BOX
    sau6  0x78077722  SMD_$DRAW_BOX

  - The four sides are drawn with the display acquired, by the
    hand-written SMD_$HORIZ_LINE and SMD_$VERT_LINE.

  Status stored:
    smd_$util_init's status: always; the box is drawn only when it is
      status_$ok
}

{ TODO(pascal) frame of SMD_$DRAW_BOX not accounted

  The image's frame is 0x24 bytes: ctx at -0x20 (0x1C bytes, the
  context's 0x1A rounded) and control at -0x22 take 0x1E bytes; the 4
  bytes at -0x4..-0x1 above ctx and the 2 at -0x24 (rounding) are not
  explained.  The declaration order (control first, then ctx) would put
  control above ctx; ctx first puts it at -0x1C, not -0x20, unless the
  compiler gives the 0x1A-byte record a 4-byte-aligned slot of 0x1C
  below a 4-byte hole.  Not settled (dpc: ctx at -0x1C, control at
  -0x1E, a frame of 0x20). }

procedure smd_$draw_box(in box_desc: smd_$window_limits_t;
                        out status: status_$t);
var
  ctx: smd_ws_ctx_t;
  control: integer;
begin
  smd_$util_init(ctx);
  status := ctx.status;
  if status.all <> status_$ok then
    return;

  control := smd_$acq_display(1);
  with box_desc do begin
    smd_$horiz_line(ys, xs, xe, ctx.display_base, ctx.ctrl_regs,
                    control, ctx.hw);
    smd_$vert_line(xe, ys, ye, ctx.display_base, ctx.ctrl_regs,
                   control, ctx.hw);
    smd_$horiz_line(ye, xs, xe, ctx.display_base, ctx.ctrl_regs,
                    control, ctx.hw);
    smd_$vert_line(xs, ys, ye, ctx.display_base, ctx.ctrl_regs,
                   control, ctx.hw);
  end;
  smd_$rel_display;
end;
