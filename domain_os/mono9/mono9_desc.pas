{ mono9/mono9_desc.pas - the MONO9_DESC module, the display's descriptor
  and its routine vector, configuration and state.

  Image addresses:
    sau9  0x3C433600  MONO9_DESC data (DCTES, 0x40 bytes)
    sau9  0x3C43399C  MONO9_$WIRED_DATA overlay (0xC8 bytes)

  A map module of data only, `module mono9_desc, , dctes;': the map's
  MONO9_DESC segment in the load section DCTES (the SAU9's dynamic DCTE
  area, with DCTE_START and DCTE_$NULL at its start), the display's
  DCTE, MONO9_$UNIT.  And the contents of the overlay section
  MONO9_$WIRED_DATA (the map's load section, no module segment in it;
  ref 3.14), which the DCTE points into: the routine vector, the state
  and the configuration (mono9/mono9.ins.pas).  Which unit gave the
  overlay its bytes is not known; the descriptor is the one that names
  it.

  With the part mono9_display (base/config.ins.pas), empty elsewhere.

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module mono9_desc, , dctes;

%include 'base/base.ins.pas';
%if mono9_display %then
%include 'proc1/proc1.ins.pas';
%include 'smd/smd.ins.pas';
%include 'mono9/mono9.ins.pas';

{ The overlay section, the variable named after it (ring/ringlog.ins.pas's
  form), with the image's bytes. }
var (mono9_$wired_data)
  mono9_$wired_data: mono9_$wired_data_t :=
    [hdm := [field_00 := 1,
             video_ctl := addr(mono9_$video_ctl),
             copy_font_md_hdm := addr(mono9_$copy_font_md_hdm),
             lock_display := addr(mono9_$lock_display),
             blink_cursor := addr(mono9_$blink_cursor),
             xor_cursor := addr(mono9_$xor_cursor),
             map_disp := addr(mono9_$map_disp),
             unmap_disp := addr(mono9_$unmap_disp),
             install_disp := addr(mono9_$install_disp),
             assoc := addr(mono9_$assoc),
             dissoc := addr(mono9_$dissoc),
             clear_screen := addr(mono9_$clear_screen),
             display_logo := addr(mono9_$display_logo),
             set_color_table := addr(mono9_$set_color_table),
             hw_uid := [high := 16#4028C15E, low := 16#10014527],
             disp_type := 15,               { gpr_$mono9_2kx1k }
             line_bits := 2048,
             word_74 := 1024,
             width := 1280,
             height := 1024],
     config := [memory_addr := 16#3FFA0000,
                word_10 := 16#0100,
                word_14 := 16#0100,
                word_16 := 16#FF00,
                word_18 := 16#0001,
                word_1a := 16#0004]];

{ The descriptor, MONO9_$UNIT (map symbol, defined here; ref 7.2.1,
  Method 1). }
var
  mono9_$unit: define mono9_$dcte_t :=
    [kind := mono9_$dcte_kind, length := 64, ctype := mono9_$dcte_ctype,
     cnum := 0, nextp := nil, csrsytr := addr(mono9_$ioinit),
     name := 'mono    ',
     tag := ['C', chr(0), chr(0), 'M', 'O', 'M', ' ', chr(0), chr(0),
             chr(0), chr(0), chr(0)],
     hdm := addr(mono9_$wired_data.hdm),
     info := addr(mono9_$wired_data.info),
     config := addr(mono9_$wired_data.config)];
%endif
