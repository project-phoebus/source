{ SMD_$INIT - initialize the display driver at boot.

  Image addresses:
    sau2  0x00E34D2C  SMD_$INIT
    sau5  0x00E36F04  SMD_$INIT
    sau9  0x3C43B478  SMD_$INIT

  - Each unit (one here) gets its font table, hidden-memory list, display
    memory, registers, display record and UID; its controller is probed
    and the display's type and limits set.
  - With `two_display_units' (base/config.ins.pas) unit 1 takes the
    block's second font table and free list, unit 2 the first.
  - With `gpu_driver' the graphics board's id chooses unit 1's display
    (the DN580's or the DN570's) and no unit is probed; with
    `color_board' a silent unit 2 is probed as the color board.
  - With `display_devices' each of the eight units takes the device
    SMD_$ADD_DEVICE gave it, or none; the device's areas are wired
    and its type and size give the display's.
  - The `case' on the constant init_case (0) is the image's dispatch of
    a constant over a table of four entries.

  Status stored: none.
}

{ TODO(pascal) frame of SMD_$INIT not accounted

  The frame is 0x20 bytes; the code addresses only probe_data.  The
  declared locals (probe_data 4, u 2, i 2) and the `with' slot of
  unit[u] (4) give 12 bytes; 20 bytes are not explained.  dpc's layout
  gives the routine as written 12 bytes.  The SAU5's frame is 0x34
  bytes: gdev_probe at -6, probe_data's home at -4 (the image keeps it
  in a register and stores it there around each TESTPAGE), the `with'
  pointer at -0x34; the rest is not explained either. }

[section(os_init_proc, os_init_data)]
procedure smd_$init;
%if display_devices %then
var
  u: integer;
  i: integer;
  page_list: array[1..20] of integer32;
  page_count: integer;
begin
  { each unit's device and display }
  for u := 1 to smd_unit_count do
    with smd_$wired_data.unit[u] do begin
      { no device beyond the ones added; a device's areas are wired }
      if u > smd_$wired_data.unit_count then
        vector := nil
      else
        for i := 1 to vector^.n_areas do
          with vector^.areas^[i] do
            if start_va <> nil then begin
              mst_$wire_area(start_va, end_va, page_list, 20, page_count);
              start_va := nil;
            end;

      { the unit's and the display's state }
      hw := addr(smd_$display_com[u]);
      owner_asid := 0;
      borrowed_asid := 0;
      field_0a := 0;
      with hw^ do begin
        disp_limits.ys := 0;
        disp_limits.xs := 0;
        lock_state := 0;
        ec_$init(lock_ec);
        tracking_enabled := false;
        field_20 := false;
        video_flags := 1;
        field_24 := 0;
        field_3e := chr(0);
        field_5e := 0;
        ec_$init(cursor_ec);
        field_4c := [];

        { no process has the display mapped }
        for i := 1 to 57 do
          mapped_addresses[i] := nil;
        font_table := addr(unit_fonts);
        hdm_list := addr(unit_hdm_list);
        if vector <> nil then
          display_type := vector^.disp_type;

        { the blanking clock and timeout }
        blank_time := 0;
        blank_timeout := 3433;
        ml_$exclusion_init(smd_$wired_data.trk_rect_mutex);

        { the display's limits, the device's size }
        if vector <> nil then begin
          disp_limits.ye := vector^.height - 1;
          disp_limits.xe := vector^.width - 1;
        end;
      end;
    end;

  { the section's two eventcounts }
  ec_$init(smd_$wired_data.ec_1);
  ec_$init(smd_$wired_data.ec_2);
end;
%else
%if two_display_units %then
var
  disp_kind: integer;
%if gpu_driver %then
  gdev_probe: integer;
%endif
  probe_data: integer;
%else
const
  init_case = 0;
var
  probe_data: integer32;
%endif
  u: integer;                             { the body does not read it }
  i: integer;
begin
  { the section's two eventcounts }
  ec_$init(smd_$wired_data.ec_1);
  ec_$init(smd_$wired_data.ec_2);

%if two_display_units %then
  disp_kind := 1;
%if gpu_driver %then
  { the graphics board, when one answers, and its kind of display }
  if testpage(1, addr(kolor_ctl), gdev_probe) then
    smd_$graphic_device_id := kolor_ctl.device_id
  else
    smd_$graphic_device_id := 0;
  case smd_$graphic_device_id of
    0: { empty };
    smd_gdev_color2: disp_kind := 2;
    smd_gdev_color3: disp_kind := 3;
  end;
%endif

  { unit 1's record }
  case disp_kind of
    0, 1: begin
      smd_$wired_data.unit[1].font_table := addr(unit1_fonts);
      smd_$wired_data.unit[1].hdm_list := addr(unit1_hdm_list);
      smd_$wired_data.unit[1].display_base := addr(disp1_mem);
      smd_$wired_data.unit[1].ctrl_regs := addr(disp1);
      smd_$wired_data.unit[1].hw := addr(smd_$display_com[1]);
      smd_$wired_data.unit[1].hw^.display_type := smd_$none;
      smd_$wired_data.unit[1].display_uid := display1_$uid;
    end;
%if gpu_driver %then
    2: begin
      smd_$wired_data.unit[1].font_table := addr(unit1_fonts);
      smd_$wired_data.unit[1].hdm_list := addr(unit1_hdm_list);
      smd_$wired_data.unit[1].display_base := addr(disp_mem_2kx1k);
      smd_$wired_data.unit[1].ctrl_regs := addr(kolor_ctl);
      smd_$wired_data.unit[1].hw := addr(smd_$display_com[1]);
      smd_$wired_data.unit[1].hw^.display_type := smd_$color2_display;
      smd_$wired_data.unit[1].display_uid := display3_$uid;
    end;
    3: begin
      smd_$wired_data.unit[1].font_table := addr(unit1_fonts);
      smd_$wired_data.unit[1].hdm_list := addr(unit1_hdm_list);
      smd_$wired_data.unit[1].display_base := addr(disp1_mem);
      smd_$wired_data.unit[1].ctrl_regs := addr(kolor_ctl);
      smd_$wired_data.unit[1].hw := addr(smd_$display_com[1]);
      smd_$wired_data.unit[1].hw^.display_type := smd_$color3_display;
      smd_$wired_data.unit[1].display_uid := display1_$uid;
    end;
%else
    2, 3: { empty };
%endif
  end;

  { unit 2's record }
  smd_$wired_data.unit[2].font_table := addr(unit_fonts);
  smd_$wired_data.unit[2].hdm_list := addr(unit_hdm_list);
  smd_$wired_data.unit[2].display_base := addr(disp2_mem);
  smd_$wired_data.unit[2].ctrl_regs := addr(disp2);
  smd_$wired_data.unit[2].hw := addr(smd_$display_com[2]);
  smd_$wired_data.unit[2].hw^.display_type := smd_$none;
  smd_$wired_data.unit[2].display_uid := display2_$uid;
%else
  { unit 1's record }
  case init_case of
    0: begin
      smd_$wired_data.unit[1].font_table := addr(unit_fonts);
      smd_$wired_data.unit[1].hdm_list := addr(unit_hdm_list);
      smd_$wired_data.unit[1].display_base := addr(disp1_mem);
      smd_$wired_data.unit[1].ctrl_regs := addr(disp1);
      smd_$wired_data.unit[1].hw := addr(smd_$display_com[1]);
      smd_$wired_data.unit[1].hw^.display_type := smd_$none;
      smd_$wired_data.unit[1].display_uid := display1_$uid;
    end;
    1, 2, 3: { empty };
  end;
%endif

  { each unit's display }
  for u := 1 to smd_unit_count do
    with smd_$wired_data.unit[u], hw^ do begin
      owner_asid := 0;
      borrowed_asid := 0;

%if two_display_units %then
      { a controller that answers tells its display's type; unit 2 may
        be the color board's }
%if gpu_driver %then
      if smd_$graphic_device_id = 0 then
%endif
      begin
        if testpage(1, ctrl_regs, probe_data) then
          display_type := smd_$get_dtype(display_base, ctrl_regs)
%if color_board %then
        else if u = 2 then
          if testpage(1, addr(color_sup), probe_data) then begin
            color_sup.command := 8;
            probe_data := color_cstore[3];
            color_sup.command := 9;
            color_sup.command := 8;
            color_sup.command := 14;
            repeat
            until not (13 in color_sup.status);
            if (1 in color_sup.config) and then (probe_data <> 256) then
              display_type := smd_$800_color
            else
              display_type := smd_$color_display;
            ctrl_regs := addr(color_sup);
          end
%endif
      end;
%else
      { a controller that answers is the landscape one }
      if testpage(1, ctrl_regs, probe_data) then
        display_type := smd_$bw_19l;
%endif

      { the display's limits }
      disp_limits.ys := 0;
      disp_limits.xs := 0;
      case display_type of
        smd_$bw_15p: begin
          disp_limits.ye := 1023;
          disp_limits.xe := 799;
        end;
%if color_board %then
        smd_$color_display: begin
          disp_limits.ye := 1023;
          disp_limits.xe := 1023;
        end;
%endif
%if gpu_driver %then
        smd_$color2_display: begin
          disp_limits.ye := 1023;
          disp_limits.xe := 1279;
        end;
%endif
        smd_$bw_19l
%if color_board %then
          , smd_$800_color
%endif
%if gpu_driver %then
          , smd_$color3_display
%endif
          : begin
          disp_limits.ye := 799;
          disp_limits.xe := 1023;
        end;
      end;

      { the unit's and the display's state }
      field_0a := 0;
      lock_state := 0;
      ec_$init(lock_ec);
      ec_$init(op_ec);
      field_1c := 0;
      tracking_enabled := false;
      field_20 := false;
      video_flags := 1;
      field_24 := 0;
      field_3e := chr(0);
      field_5e := 0;
      ec_$init(cursor_ec);
      field_4c := [];

      { no process has the display mapped }
      for i := 1 to 57 do
        mapped_addresses[i] := nil;
    end;

  smd_$interrupt_init;

  { the blanking clock and timeout }
  blank_time := 0;
  blank_timeout := 3433;

  ml_$exclusion_init(smd_$wired_data.trk_rect_mutex);
end;
%endif
