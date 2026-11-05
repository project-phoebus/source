{ tpad/tpad.pas - the TPAD module, the touchpad/tablet locator.

  Image addresses:
    sau2  0x00E8245C  TPAD data (.DATA, 0x180 bytes)
    sau4  0x0F890BD0  TPAD data (.DATA, 0x180 bytes)
    sau6  0x7809CB34  TPAD data (.DATA, 0x1A8 bytes)
    sau7  0x3C4AB750  TPAD data (.DATA, 0x180 bytes)

  One compilation unit, in two code sections and one data section: the
  map's TPAD code segments in OS_INIT_PROC (0xFC bytes, TPAD_$INIT) and
  in .TEXT (0x9C0 bytes, TPAD_$DATA .. TPAD_$INQ_PUNCH_IMPACT; the
  SAU4's 0x994, its multiplies the -cpu 460 instructions), and its
  TPAD data segment in .DATA (0x180 bytes), with no map symbol inside.

  The data, 0x180 bytes:

    +0x000  tpad_$unit_configs  8 x 0x2C  the unit records
                                (tpad/tpad.ins.pas)
    +0x160  tpad_$cursor        4   one smd_$pos_t (line, column)
    +0x164  tpad_$last_clock    6
    +0x16A  tpad_$touchpad_max  2
    +0x16C  tpad_$dev_type      2

    +0x16E  tpad_$raw_y         2
    +0x170  tpad_$raw_x         2
    +0x172  tpad_$button_state  2
    +0x174  tpad_$delta_y       2
    +0x176  tpad_$delta_x       2

    +0x178  tpad_$accum_y       2
    +0x17A  tpad_$accum_x       2
    +0x17C  tpad_$unit          2   the current unit
    +0x17E  tpad_$re_origin_flag 1
    +0x17F  1 byte of rounding (the block is padded to 4, as LOG_'s
            +0x19)

  With `tpad_block_head' (base/config.ins.pas) the block is 0x1A8 bytes:
  40 bytes, zero in the image, before the unit records (tpad_head), and
  every offset above 0x28 on.

  These are module-level variables (the LOG and KBD model, log/log.pas,
  kbd/kbd.pas), used by routines in both code sections, and the block's
  order is not the routines'.  The defaults are the sections that hold
  the module's code and data, so the heading names no sections; TPAD_$INIT
  is headed `[section(os_init_proc, os_init_data)]' and reaches the
  block by its address.

  The routines live in one fragment file per routine pair
  (tpad/<name>.pas), included below in image order.  The wrappers call
  their unit routines forward, as declared by the extern headings of
  tpad.ins.pas.

  Only the SAUs with the display driver have the module (the part
  `display_driver', base/config.ins.pas); the SAU3's map has no TPAD
  segment, so there the whole body is configured out.

  Build: dpc -I domain_os domain_os/tpad/tpad.pas.  Check:
  tools/pascal_check.sh.
}
module tpad;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%if display_driver %then
%include 'time/time.ins.pas';
%include 'smd/smd.ins.pas';
%include 'tpad/tpad.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  tpad_$init;
  tpad_$data;
  tpad_$set_mode;
  tpad_$set_unit_mode;
  tpad_$set_cursor;
  tpad_$set_unit_cursor;
  tpad_$inquire;
  tpad_$inquire_unit;
  tpad_$set_unit;
  tpad_$re_range;
  tpad_$re_range_unit;
  tpad_$inq_dtype;
  tpad_$set_punch_impact;
  tpad_$inq_punch_impact;

{ The module's variables (ref 3.2.2 p. 3-4, 3.11.1: initial values of
  module variables), in the order of the block, the bytes in comments.
  Bytes that the initializers do not name are zero in the image, as the
  whole of LOG_'s block is (log/log.pas, uninitialized). }
var
%if tpad_block_head %then
  { +0x000: 40 bytes, zero in the image; TPAD_$INIT tests the boolean
    at +0x05, and nothing else addresses them. }
  tpad_head: record
    unused_0: array[0..4] of char;
    flag_5: boolean;
    unused_6: array[6..39] of char;
  end;

%endif
  { +0x000: eight unit records of 0x2C bytes, each initialized in the
    image: sample_count 0, mode tpad_$absolute, x_scale and y_scale 99,
    x_range and y_range 16#200, x_min and y_min 16#100, the display
    limits 0 .. 99 on both axes, hysteresis 5, the rest 0.  Nothing at
    boot rewrites them before TPAD_$INIT (COLD_START neither copies nor
    zeroes .DATA), which sets the scales, the
    maximum limits and the factors from each display present. }
  tpad_$unit_configs: array[1..tpad_$max_units] of tpad_$unit_config_t := [
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 1, +0x000 }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 2, +0x02C }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 3, +0x058 }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 4, +0x084 }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 5, +0x0B0 }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 6, +0x0DC }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5],                    { unit 7, +0x108 }
    [x_scale := 99, y_scale := 99, x_range := 16#200, y_range := 16#200,
     x_min := 16#100, y_min := 16#100, x_max_disp := 99, y_max_disp := 99,
     hysteresis := 5]];                   { unit 8, +0x134 }

  { +0x160 .. +0x17F: all zero in the image; TPAD_$INIT sets the
    cursor, the touchpad maximum and the device type at boot. }
  tpad_$cursor: smd_$pos_t;               { +0x160: line, +0x162: column }
  tpad_$last_clock: time_$clock_t;        { +0x164 }
  tpad_$touchpad_max: integer;            { +0x16A }
  tpad_$dev_type: tpad_$dev_type_t;       { +0x16C }
  tpad_$raw_y: integer;                   { +0x16E }
  tpad_$raw_x: integer;                   { +0x170 }
  tpad_$button_state: integer;            { +0x172 }
  tpad_$delta_y: integer;                 { +0x174 }
  tpad_$delta_x: integer;                 { +0x176 }
  tpad_$accum_y: integer;                 { +0x178 }
  tpad_$accum_x: integer;                 { +0x17A }
  tpad_$unit: integer;                    { +0x17C }
  tpad_$re_origin_flag: boolean;          { +0x17E }

{ ---- OS_INIT_PROC ---- }
%include 'tpad/init.pas';                   { TPAD_$INIT }

{ ---- .TEXT ---- }
%include 'tpad/data.pas';                   { TPAD_$DATA }
%include 'tpad/set_mode.pas';               { TPAD_$SET_MODE }
%include 'tpad/set_unit_mode.pas';          { TPAD_$SET_UNIT_MODE }
%include 'tpad/set_cursor.pas';             { TPAD_$SET_CURSOR }
%include 'tpad/set_unit_cursor.pas';        { TPAD_$SET_UNIT_CURSOR }
%include 'tpad/inquire.pas';                { TPAD_$INQUIRE }
%include 'tpad/inquire_unit.pas';           { TPAD_$INQUIRE_UNIT }
%include 'tpad/set_unit.pas';               { TPAD_$SET_UNIT }
%include 'tpad/re_range.pas';               { TPAD_$RE_RANGE }
%include 'tpad/re_range_unit.pas';          { TPAD_$RE_RANGE_UNIT }
%include 'tpad/inq_dtype.pas';              { TPAD_$INQ_DTYPE }
%include 'tpad/set_punch_impact.pas';       { TPAD_$SET_PUNCH_IMPACT }
%include 'tpad/inq_punch_impact.pas';       { TPAD_$INQ_PUNCH_IMPACT }
%endif
