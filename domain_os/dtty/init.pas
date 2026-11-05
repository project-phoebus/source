{ DTTY_$INIT - set up the display TTY.

  Image addresses:
    sau2  0x00E34BD0  DTTY_$INIT
    sau3  0x00E32F18  DTTY_$INIT
    sau4  0x0F837E84  DTTY_$INIT
    sau5  0x00E36D18  DTTY_$INIT
    sau6  0x7803E474  DTTY_$INIT
    sau7  0x3C43E29C  DTTY_$INIT
    sau9  0x3C43B26C  DTTY_$INIT

  - The display TTY is used when mode is 1, or mode is 0 and the
    display's status word has bit 0; a display type it does not know
    ends the routine.
  - Otherwise the display is associated with the current process, its
    window cleared and the standard font loaded; the first failure is
    printed on the console (dtty_$report_error).
  - With `gpu_driver' or `second_display_unit' (base/config.ins.pas) the
    color displays are taken too; their status word is 2.
  - With `smd_display_memory' unit 1 is taken whatever its type, its
    window from SMD_$INQ_DISP_INFO's sizes, and the display TTY is used
    when mode is 0 or 1.
  - Without `display_driver' there is no display: the routine only
    stores the control word and sets DTTY_$USE_DTTY.

  Status stored: none.
}

{ TODO(pascal) 36 frame bytes of DTTY_$INIT hold nothing the code
  addresses

  The stand-ins unused_20 (16 bytes) and unused_40 and unused_44 (20
  bytes: 16 at a multiple of 8 from A6 and a longword, since one 20-byte
  object would be placed at a multiple of 8 and these bytes do not start
  at one) hold their places in the SAU2 frame, between info and the
  window and below disp_status.  The addressed objects are info (the
  `smd_display_memory' form's SMD_$INQ_DISP_INFO result, at the top of
  every SAU's frame), the window, the status and the unit word;
  disp_status is held in a register.  The SAU7..SAU9 frames are 4
  bytes smaller (no unused_44).  Nothing explains the 16 bytes above
  the window or the 16 below disp_status.  Not settled.  Without
  `display_driver' (the SAU3) the frame is 0x2C bytes and the code
  addresses none of it; the declarations kept there (info, unused_20,
  the window and the status) are one choice of locals that gives that
  size. }

[section(os_init_proc, os_init_data)]
procedure dtty_$init(in mode: integer; in ctrl: integer);
var
  info: smd_disp_info_result_t;           { the `smd_display_memory' form's }
  unused_20: array[1..16] of char;        { the stand-in: TODO above }
  window: smd_$window_limits_t;
  status: status_$t;
%if display_driver %then
  assoc_unit: integer;
  disp_status: pinteger;
  unused_40: array[1..16] of char;        { the stand-in: TODO above }
%if not smd_display_memory %then
  unused_44: integer32;
%endif
%endif
begin
  dtty_$ctrl := ctrl;
  dtty_$use_dtty := true;
%if not display_driver %then
end;
%else
%if smd_display_memory %then
  assoc_unit := 1;
  smd_$inq_disp_info(assoc_unit, info, status);
  window.ye := info.dims.width - 1;
  window.xe := info.dims.height - 1;

  dtty_$use_dtty := (mode = 0) or (mode = 1);
%else
  dtty_flag_06 := true;
  dtty_flag_04 := false;
  dtty_$disp_type := smd_$inq_disp_type(dtty_display_unit);

  case dtty_$disp_type of
%if second_display_unit %then
    smd_$none: begin
      dtty_$disp_type := smd_$inq_disp_type(dtty_second_display_unit);
      case dtty_$disp_type of
        smd_$color_display: begin
          assoc_unit := 2;
          window.xe := 16#3FF;
          window.ye := 16#3FF;
        end;
        smd_$800_color: begin
          assoc_unit := 2;
          window.xe := 16#3FF;
          window.ye := 16#31F;
        end;
        otherwise begin
          return;
        end;
      end;
      dtty_flag_06 := false;
      dtty_flag_04 := true;
      disp_status := 2;
    end;
%endif
%if gpu_driver %then
    smd_$color2_display: begin
      assoc_unit := 1;
      window.xe := 16#4FF;
      window.ye := 16#3FF;
      dtty_flag_06 := false;
      disp_status := 2;
    end;
    smd_$color3_display: begin
      assoc_unit := 1;
      window.xe := 16#3FF;
      window.ye := 16#31F;
      dtty_flag_06 := false;
      disp_status := 2;
    end;
%endif
    smd_$bw_15p: begin
      assoc_unit := 1;
      disp_status := disp1_mem[16#33];
      window.xe := 16#31F;
      window.ye := 16#3FF;
    end;
    smd_$bw_19l: begin
      assoc_unit := 1;
      disp_status := disp1_mem[16#F5F3];
      window.ye := 16#31F;
      window.xe := 16#3FF;
    end;
    otherwise begin
      return;
    end;
  end;

  dtty_$use_dtty := (odd(disp_status) and (mode = 0)) or (mode = 1);
%endif
  if dtty_$use_dtty then
    return;
  dtty_$ctrl := 0;

  smd_$assoc(assoc_unit, proc1_$current, status);
  if status.all <> status_$ok then begin
    dtty_$report_error(status, 'smd_$assoc%$', '$');
    return;
  end;
  window.xs := 0;
  window.ys := 0;
  dtty_$clear_window(window, status);
  if status.all <> status_$ok then begin
    dtty_$report_error(status, 'dtty_$clear_window%$', '$');
    return;
  end;
  discard(dtty_$load_font(dtty_$std_font_p, status));
  if status.all <> status_$ok then
    dtty_$report_error(status, 'smd_$copy_font_to_md_hdm%$', '$');
end;
%endif
