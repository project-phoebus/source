{ SMD_$SOFT_SCROLL - start a soft scroll of a window of the screen.

  Image addresses:
    sau2  0x00E6F326  SMD_$SOFT_SCROLL
    sau4  0x0F879A6E  SMD_$SOFT_SCROLL
    sau5  0x00E716DA  SMD_$SOFT_SCROLL

  - The hand-written SMD_$START_SCROLL starts the scroll; the routine
    returns before it completes, the process noted as the operation's
    waiter.
  - The heading is Apollo's smd_$soft_scroll_u's (smdu.ins.pas).
  - With `color_displays' a color display is refused after the display
    is acquired.

  Status stored:
    status_$ok: the scroll was started
    smd_$illegal_caller: the process has no display unit
    smd_$not_on_color: with `color_displays' (base/config.ins.pas), a
      color display (types 3..6)
}

{ TODO(pascal) SMD_$SOFT_SCROLL's frame: 4 of its 0x10 bytes not accounted

  The image's frame has 16 bytes and addresses no frame slot: unit_num,
  disp and the `with' pointers are held in registers.  dpc's layout of
  the two locals and the `with' slot (`--dump-locals' on the gate's copy)
  is 12 bytes; the other 4 (a second `with' slot for `with disp^'?) are
  not accounted. }

procedure smd_$soft_scroll(in window_desc: smd_$window_limits_t;
                           in direction: smd_$direction_t;
                           in displacement: pinteger;
                           out status: status_$t);
var
  unit_num: pinteger;
  disp: smd_display_hw_ptr_t;
begin
  unit_num := asid_to_unit[proc1_$as_id];
  if unit_num = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  discard(smd_$acq_display(0));
  with smd_$wired_data.unit[unit_num] do begin
    disp := hw;
    with disp^ do begin
%if color_displays %then
      if display_type in [smd_$color_display..smd_$color3_display] then
        begin
        status.all := smd_$not_on_color;
        return;
        end;
%endif
      scroll_window := window_desc;
      scroll_dx := direction;
      scroll_dy := displacement;
    end;
    smd_$start_scroll(disp^, ctrl_regs);
    field_08 := proc1_$as_id;
  end;
  status.all := status_$ok;
end;
