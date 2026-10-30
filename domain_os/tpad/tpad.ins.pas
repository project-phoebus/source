{ tpad/tpad.ins.pas - the touchpad/tablet locator (TPAD): constants,
  types and the routine headings, for the Domain Pascal tree.

  Include base/base.ins.pas, time/time.ins.pas and smd/smd.ins.pas
  before it.

  Apollo's customer tpad.ins.pas of SR10.2 (sr10.2-install/install/
  ri.apollo.os.v.10.2/sys/ins/tpad.ins.pas, "TPAD.INS.PAS, /US/INS, JAH,
  12/10/81") declares the two enumerations and the user routines
  TPAD_$SET_MODE, TPAD_$INQUIRE, TPAD_$RE_RANGE, TPAD_$SET_CURSOR and
  TPAD_$INQ_DTYPE; their names, types and parameter names are used
  below.

  The unit routines, TPAD_$INIT, TPAD_$DATA, the packet and the
  per-unit record have no Apollo declaration.
}

const
  { The display units the module keeps a record for: the TPAD data
    block holds eight 0x2C-byte records, 0x160 bytes, before the scalars
    at +0x160 (tpad/tpad.pas). }
  tpad_$max_units = 8;

type
  { The operating mode, as Apollo's tpad.ins.pas declares it:
    `tpad_$mode_t = (tpad_$absolute, tpad_$relative, tpad_$rel_abs);'. }
  tpad_$mode_t = (tpad_$absolute, tpad_$relative, tpad_$rel_abs);

  { The last device seen, as Apollo's tpad.ins.pas declares it:
    `tpad_$dev_type_t = (tpad_$unknown, tpad_$have_touchpad,
    tpad_$have_mouse, tpad_$have_bitpad);'. }
  tpad_$dev_type_t = (tpad_$unknown, tpad_$have_touchpad,
                      tpad_$have_mouse, tpad_$have_bitpad);

  { A byte of a packet, read as an unsigned or a signed 8-bit integer
    (ref 3.15.5, size attributes: "[byte] 0..255 corresponds to the
    unsigned char data type in Domain/C"): TPAD_$DATA masks the bytes,
    which a char could not be (it has no `&'), and reads the mouse's
    sign-extended through a type transfer (ref 4-197). }
  tpad_$byte_t = [byte] 0..255;
  tpad_$signed_byte_t = [byte] -128..127;

  { One packet as TPAD_$DATA reads it, 16 bytes: a sample of
    TERM_$TPAD_BUFFER, which suma/suma.ins.pas declares as
    suma_sample_t, read with another type (the time unsigned, the bytes
    0xB .. 0xF integers), so TPAD has its own.
    - elapsed 0x00: the microseconds since the previous packet,
      linteger (ref 4.3.3);
    - clock 0x04: the 48-bit clock, a time_$clock_t;
    - dev_id 0x0A, flags 0x0B, b0 .. b3 0x0C .. 0x0F: tpad_$byte_t
      (above). }
  { TODO(pascal) TERM_$ENQUEUE_TPAD's sample: a `univ' formal or one type

    TERM_$ENQUEUE_TPAD's argument is a suma_sample_t; when OS_TERM_INIT
    is translated, its call needs either this formal `univ' or one type
    for the queue's samples (a variant record would cover both
    readings); the image cannot tell which. }
  tpad_$data_packet_t = record
    elapsed: linteger;                    { 0x00 }
    clock: time_$clock_t;                 { 0x04 }
    dev_id: tpad_$byte_t;                 { 0x0A: 0xDF mouse, 1 bitpad,
                                            else touchpad }
    flags: tpad_$byte_t;                  { 0x0B }
    b0: tpad_$byte_t;                     { 0x0C }
    b1: tpad_$byte_t;                     { 0x0D }
    b2: tpad_$byte_t;                     { 0x0E }
    b3: tpad_$byte_t;                     { 0x0F }
  end;

  { A display unit's locator settings, 0x2C bytes, element `unit' of an
    array from 1:
    - sample_count 0x00: the touchpad samples ranged, up to 1000;
    - mode 0x04: tpad_$mode_t (above);
    - x_scale 0x06, y_scale 0x08: the caller's xs and ys;
    - x_range 0x0A, y_range 0x0C, x_min 0x0E, y_min 0x10: the touchpad's
      raw range;
    - x_min_disp 0x12, x_max_disp 0x14, y_min_disp 0x16, y_max_disp 0x18:
      the cursor's limits;
    - hysteresis 0x1A;
    - x_factor 0x1C, y_factor 0x1E: range div scale, or 1024;
    - cursor_offset 0x20: the cursor's position less the raw one, an
      smd_$pos_t (smd/smd.ins.pas);
    - origin 0x24: an smd_$pos_t, Apollo's type of TPAD_$SET_MODE's
      origin;
    - punch_impact 0x28: the edge-event threshold;
    - unused_2a 0x2A: the stand-in (see the TODO(pascal) below). }
  { TODO(pascal) unused_2a: 2 bytes at 0x2A no instruction addresses

    No instruction addresses these two bytes, but the records are 0x2C
    apart (the multiplier, and the block's 0x160 bytes for eight).  Under
    the default word alignment (ref 3.10.5.5) the fields above end at
    0x2A, so the stand-in holds the place; a record rounded to the
    longword of sample_count (natural alignment, ref 3.10.5.6) would
    give the same size without it.  Not settled. }
  tpad_$unit_config_t = record
    sample_count: integer32;              { 0x00 }
    mode: tpad_$mode_t;                   { 0x04 }
    x_scale: integer;                     { 0x06 }
    y_scale: integer;                     { 0x08 }
    x_range: integer;                     { 0x0A }
    y_range: integer;                     { 0x0C }
    x_min: integer;                       { 0x0E }
    y_min: integer;                       { 0x10 }
    x_min_disp: integer;                  { 0x12 }
    x_max_disp: integer;                  { 0x14 }
    y_min_disp: integer;                  { 0x16 }
    y_max_disp: integer;                  { 0x18 }
    hysteresis: integer;                  { 0x1A }
    x_factor: integer;                    { 0x1C }
    y_factor: integer;                    { 0x1E }
    cursor_offset: smd_$pos_t;            { 0x20 }
    origin: smd_$pos_t;                   { 0x24 }
    punch_impact: integer;                { 0x28 }
    unused_2a: integer;                   { 0x2A: stand-in, see above }
  end;

{ Routine headings: the TPAD_$ routines, all global symbols in the SAU2
  map, in map order (the OS_INIT_PROC TPAD segment, then the .TEXT
  one).  The bodies repeat the full heading (ref 7.3.4, Method 2).  The
  parameter names are Apollo's where its tpad.ins.pas declares the
  routine; the unit routines' names (unitp, xsp, hysteresisp, originp,
  ...) keep them apart from the unit record's fields, which the bodies
  reach with `with' (tpad/tpad.pas). }

{ TPAD_$INIT - set up the locator at boot. }
procedure tpad_$init; extern;

{ TPAD_$DATA - turn one locator packet into cursor motion. }
procedure tpad_$data(in out sample: univ tpad_$data_packet_t); extern;

{ TPAD_$SET_MODE - set the current unit's mode, scales and hysteresis. }
procedure tpad_$set_mode(in new_mode: tpad_$mode_t; in xs, ys: integer;
                         in hysteresis: integer; in origin: smd_$pos_t);
  extern;

{ TPAD_$SET_UNIT_MODE - set a unit's mode, scales, hysteresis and origin. }
procedure tpad_$set_unit_mode(in unitp: integer; in new_modep: tpad_$mode_t;
                              in xsp, ysp: integer; in hysteresisp: integer;
                              in originp: smd_$pos_t;
                              out status_ret: status_$t); extern;

{ TPAD_$SET_CURSOR - re-origin the locator where the DM put the cursor. }
procedure tpad_$set_cursor(in new_crsr: smd_$pos_t); extern;

{ TPAD_$SET_UNIT_CURSOR - set the current unit and the cursor position. }
procedure tpad_$set_unit_cursor(in unitp: integer; in new_crsr: smd_$pos_t;
                                out status_ret: status_$t); extern;

{ TPAD_$INQUIRE - return the current unit's mode settings. }
procedure tpad_$inquire(out cur_mode: tpad_$mode_t; out xs, ys: integer;
                        out hysteresis: integer; out origin: smd_$pos_t);
  extern;

{ TPAD_$INQUIRE_UNIT - return a unit's mode, scales, hysteresis and
  origin. }
procedure tpad_$inquire_unit(in unitp: integer;
                             out cur_modep: tpad_$mode_t;
                             out xsp, ysp: integer;
                             out hysteresisp: integer;
                             out originp: smd_$pos_t;
                             out status_ret: status_$t); extern;

{ TPAD_$SET_UNIT - make a display unit the locator's current unit. }
procedure tpad_$set_unit(in unitnum: integer); extern;

{ TPAD_$RE_RANGE - restart the current unit's touchpad ranging. }
procedure tpad_$re_range; extern;

{ TPAD_$RE_RANGE_UNIT - restart a unit's touchpad ranging. }
procedure tpad_$re_range_unit(in unitp: integer; out status_ret: status_$t);
  extern;

{ TPAD_$INQ_DTYPE - return the last device type seen. }
function tpad_$inq_dtype: tpad_$dev_type_t; extern;

{ TPAD_$SET_PUNCH_IMPACT - set a unit's edge-event threshold. }
function tpad_$set_punch_impact(in unitp: integer; in impact: integer;
                                out status_ret: status_$t): integer;
  extern;

{ TPAD_$INQ_PUNCH_IMPACT - return a unit's edge-event threshold. }
procedure tpad_$inq_punch_impact(in unitp: integer; out impact: integer;
                                 out status_ret: status_$t); extern;
