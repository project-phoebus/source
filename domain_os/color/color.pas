{ color/color.pas - the COLOR_ module, the color graphics board's
  driver (the DN570/DN580 class color display of the SAU4 and SAU5).

  Image addresses:
    sau5  0x00E8C324  COLOR data (.DATA, 0x8C bytes)

  With the board (`color_board', base/config.ins.pas: the maps of the
  SAU4 and SAU5 have the module, the others none): one compilation unit
  with three code segments and one data segment.  Without the board the
  module compiles to nothing.

  On the SAU5 the map's COLOR code segments are in WIRED_PROC (0x24
  bytes, COLOR_$VIDEO_CTL), OS_INIT_PROC (0x70 bytes, COLOR_$COLD_INIT)
  and .TEXT (0x440 bytes, COLOR_$INT_INIT .. COLOR_$INQ_DONE_WAIT); its
  data segment in .DATA (0x8C bytes).  The module is the map segment's
  name, COLOR.  The hand-written COLOR_ASM is color/sau5/color_asm.s.

  COLOR_$VIDEO_CTL is headed `[section(wired_proc, wired_data)]',
  COLOR_$COLD_INIT `[section(os_init_proc, os_init_data)]' (it reaches
  the block by its address); the others are in the default sections and
  load A5 with the block.

  The data block, 0x8C bytes, zero, as the routines address it:
    +0x00  color_pages       the pages COLOR_$MAP wired, 33
    +0x84  color_page_count  their count
    +0x86  color_owner       the process that holds the board, 0 for none
    +0x88  color_associated  COLOR_$ASSOC ran (COLOR_$SHUTDOWN's test)
    +0x89  3 bytes: the block's rounding to a longword

  The routines live in one fragment file each (color/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color;

%include 'base/base.ins.pas';
%if color_board %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'smd/smd.ins.pas';
%include 'tpad/tpad.ins.pas';
%include 'suma/suma.ins.pas';
%include 'kbd/kbd.ins.pas';
%include 'term/term.ins.pas';
%include 'color/color.ins.pas';
%include 'smd/smd_internal.ins.pas';

{ TODO(sau) the SAU4 COLOR code

  The module's code below is the SAU5's.  The SAU4's COLOR segments
  differ in size (0x24, 0x74 and 0x474 bytes against the SAU5's 0x24,
  0x70 and 0x440; its COLOR_ASM 0x34 bytes against 0x9C): its own form,
  with its own part, when it is translated. }

var
  color_pages: array[0..color_max_pages - 1] of linteger;   { +0x00 }
  color_page_count: integer;                    { +0x84 }
  color_owner: pinteger;                        { +0x86 }
  color_associated: boolean;                    { +0x88 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color_$video_ctl;
  color_$cold_init;
  color_$int_init;
  color_$assoc;
  color_$dissoc;
  color_$shutdown;
  color_$map;
  color_$unmap;
  color_$load_crsr;
  color_$inq_done_wait;

{ ---- WIRED_PROC ---- }
%include 'color/video_ctl.pas';             { COLOR_$VIDEO_CTL }

{ ---- OS_INIT_PROC ---- }
%include 'color/cold_init.pas';             { COLOR_$COLD_INIT }

{ ---- .TEXT ---- }
%include 'color/int_init.pas';              { COLOR_$INT_INIT }
%include 'color/assoc.pas';                 { COLOR_$ASSOC }
%include 'color/dissoc.pas';                { COLOR_$DISSOC }
%include 'color/shutdown.pas';              { COLOR_$SHUTDOWN }
%include 'color/map.pas';                   { COLOR_$MAP }
%include 'color/unmap.pas';                 { COLOR_$UNMAP }
%include 'color/load_crsr.pas';             { COLOR_$LOAD_CRSR }
%include 'color/inq_done_wait.pas';         { COLOR_$INQ_DONE_WAIT }
%endif
