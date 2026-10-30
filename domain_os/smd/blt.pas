{ SMD_$BLT - start a bit-block transfer on the current process's display.

  Image addresses:
    sau2  0x00E6EC6E  SMD_$BLT
    sau5  0x00E710F8  SMD_$BLT

  - The display is acquired (lock word 0 for an interrupt-driven BLT,
    the mode's idone, else 1); a synchronous BLT releases it at once, an
    interrupt-driven one leaves it acquired, the process recorded.
  - The controller's parameter record is built from the request, and the
    hand-written SMD_$START_BLT starts the BLT.
  - With `blt_request_start' (base/config.ins.pas) SMD_$START_BLT takes
    the request itself and only the main-memory modes are refused.

  Status stored:
    status_$ok: the BLT was started
    smd_$illegal_caller: the process has no display unit
    smd_$not_implemented: a transfer to or from main memory, or between
      non-conforming areas
    smd_$not_on_color: with `color_displays', a color display (types
      3..6), refused before the display is acquired
}

{ TODO(pascal) 4 bytes of SMD_$BLT's frame not accounted (the image's 0x24 bytes, dpc's 0x20)

  The image's frame is 0x24 bytes; the three frame locals take 0x16 (at
  -0x10, -0x14, -0x16, as the code addresses them).  dpc's layout puts
  unit at -0x18 and disp at -0x1C, and the `with' slot below them: a
  frame of 0x20.  What the other 4 bytes held is not known.  The SAU5's
  frame (`blt_request_start') is 0x10 bytes: mode at -2, and 0xE bytes
  no instruction addresses. }

procedure smd_$blt(in blt_regs: smd_$blt_regs_t; in param2: integer32;
                   in param3: integer; out status: status_$t);
%if blt_request_start %then
var
  mode: smd_$display_modereg_t;
  unit: pinteger;
  disp: smd_display_hw_ptr_t;
%else
type
  cs_bytes_t = array[1..4] of char;
var
  hw_params: smd_hw_blt_t;
  cs: cs_bytes_t;
  mode: smd_$display_modereg_t;
  unit: pinteger;
  disp: smd_display_hw_ptr_t;
%endif
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  mode := smd_$display_modereg_t(blt_regs.mode);
  with smd_$wired_data.unit[unit] do begin
    disp := hw;
%if color_displays %then
    if disp^.display_type in
       [smd_$color_display..smd_$color3_display] then begin
      status.all := smd_$not_on_color;
      return;
    end;
%endif
    if mode.idone then
      discard(smd_$acq_display(0))
    else
      discard(smd_$acq_display(1));
%if blt_request_start %then
    if mode.from_mm or else mode.to_mm then begin
      status.all := smd_$not_implemented;
      smd_$rel_display;
      return;
    end;
    smd_$start_blt(blt_regs, disp, ctrl_regs);
%else
    if mode.from_mm or else mode.to_mm or else mode.nonconform
    then begin
      status.all := smd_$not_implemented;
      smd_$rel_display;
      return;
    end;
    cs := cs_bytes_t(blt_regs.cs);
    hw_params.control.blt := mode.blt;
    hw_params.control.dummy := 0;
    hw_params.control.noninterlace := false;
    hw_params.control.from_mm := false;
    hw_params.control.to_mm := false;
    hw_params.control.ieof := mode.ieof;
    hw_params.control.idone := mode.idone;
    hw_params.control.nonconform := cs[1] = chr(2);
    hw_params.control.decr := cs[4] = chr(16#20);
    hw_params.control.clrmode := mode.clrmode;
    hw_params.control.dispon := mode.dispon;
    hw_params.bit_pos := blt_regs.edx & 16#F;
    hw_params.field_04 := blt_regs.ssy;
    hw_params.field_06 := blt_regs.ssx;
    hw_params.y_extent :=
      -1 - abs(blt_regs.edy - blt_regs.sdy);
    hw_params.x_extent :=
      -1 - abs(rshft(blt_regs.edx, 4) - rshft(blt_regs.sdx, 4));
    hw_params.y_start := blt_regs.sdy;
    hw_params.x_start := blt_regs.sdx;
    smd_$start_blt(hw_params, disp, ctrl_regs);
%endif
    if not mode.idone then
      smd_$rel_display
    else
      field_08 := proc1_$as_id;
  end;
  status.all := status_$ok;
end;
