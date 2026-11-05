{ color7/color7_dcte.pas - the COLOR7_DCTE module, the COLOR7 unit's
  descriptor, and the driver's wired data.

  Image addresses:
    sau7  0x3C435D98  COLOR7_DCTE data (WIRED_DATA, 0x40 bytes)
    sau7  0x3C4BA62C  COLOR7_$WIRED_DATA overlay (0xA8 bytes)
    sau7  0x3C4BA6E4  COLOR7_END_DATA overlay (0x4 bytes)

  A map module of data only, `module color7_dcte, , wired_data;': the
  map's COLOR7_DCTE segment in WIRED_DATA, after COLOR7's own block, with
  the unit's DCTE, COLOR7_$DCTE, which io/dctes.pas's DEV_DCTES lists.
  And the contents of the overlay section COLOR7_$WIRED_DATA (the map's
  load section, no module segment in it; ref 3.14), which the DCTE
  points into: the driver's areas, the routine vector and the unit's
  state; and the overlay section COLOR7_END_DATA after COLOR7_STATIC, 4
  zero bytes, the end of the driver's data area.  The board needs no I/O
  map request: its registers and memory are at fixed addresses.

  With the part color7_driver (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module color7_dcte, , wired_data;

%include 'base/base.ins.pas';
%if color7_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'smd/smd.ins.pas';
%include 'color7/color7.ins.pas';

type
  { The overlay section COLOR7_$WIRED_DATA's contents, 0xA8 bytes: the
    driver's areas, its vector and the unit's state. }
  color7_wired_data_t = record
    areas: color7_$areas_t;               { 0x00 }
    hdm: color7_$hdm_t;                   { 0x10 }
    info: color7_$info_t;                 { 0x94 }
  end;

{ The overlay sections, the variables named after them
  (ring/ringlog.ins.pas's form), with the image's bytes.  The data area
  runs from COLOR7_$WIRED_DATA over COLOR7_STATIC (color7/color7.pas) to
  COLOR7_END_DATA. }
var (color7_end_data)
  color7_end_data: integer32 := 0;

var (color7_$wired_data)
  color7_$wired_data: color7_wired_data_t :=
    [areas := [[start_va := addr(color7_$wired_data),
                end_va := addr(color7_end_data)],
               [start_va := addr(color7_$start_wired_proc),
                end_va := addr(color7_$end_wired_proc)]],
     hdm := [field_00 := 1,
             shutdown := addr(color7_$shutdown),
             video_ctl := addr(color7_$video_ctl),
             cold_init := addr(color7_$cold_init),
             load_crsr := addr(color7_$load_crsr),
             copy_font := addr(color7_$copy_font_md_hdm),
             lock_display := addr(color7_$lock_display),
             blink_cursor := addr(color7_$blink_cursor),
             xor_cursor := addr(color7_$xor_cursor),
             map := addr(color7_$map_display_memory),
             lites := addr(color7_$lites),
             assoc := addr(color7_$assoc_csrs),
             dissoc := addr(color7_$dissoc),
             busy_wait := addr(color7_$busy_wait),
             clear_screen := addr(color7_$clear_screen),
             putc := addr(color7_$putc),
             display_logo := addr(color7_$display_logo),
             hw_uid := [high := 16#34768C78, low := 16#90002640],
             disp_type := 14,               { smd_$color7_display }
             line_bits := 1280,
             word_74 := 1024,
             width := 1280,
             height := 1024,
             n_areas := 2,
             areas := addr(color7_$wired_data.areas)]];

{ The descriptor (map symbol, defined here; ref 7.2.1, Method 1). }
var
  color7_$dcte: define color7_$dcte_t :=
    [kind := color7_$dcte_kind, length := 64, ctype := color7_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(color7_$ioinit),
     hdm := addr(color7_$wired_data.hdm),
     info := addr(color7_$wired_data.info),
     config := nil];
%endif
