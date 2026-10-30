{ color2/color2.pas - the COLOR2_ module, the driver of the color
  displays on the graphics board (the DN580's and the DN570's).

  Image addresses:
    sau5  0x00E8C3B0  COLOR2 data (.DATA, 8 bytes)

  With the graphics board (`gpu_driver', base/config.ins.pas: the maps
  of the SAU5 and SAU6 have the module): one compilation unit with two
  code segments and one data segment.  On the SAU5 the map's COLOR2 code
  segments are in WIRED_PROC (0x5C bytes, COLOR2_$VIDEO_CTL) and .TEXT
  (0x458 bytes, COLOR2_$COLD_INIT .. COLOR2_$DISABLE_GPU_INT); its data
  segment in .DATA (8 bytes).

  Without the board the module compiles to nothing.

  The hand-written COLOR2_ASM (COLOR2_$INT_DECODE, COLOR2_$INT_EC) is
  color2/sau5/color2_asm.s.

  The board is either of two displays, by SMD_$GRAPHIC_DEVICE_ID: the
  DN580's (smd_gdev_color2), driven through the board's control word at
  +0x700C, and the DN570's (smd_gdev_color3), through the write-only
  word at +0x7020 and its copy COLOR3_$CR_CONTENTS.  Each has its own
  owner word in the block.

  COLOR2_$VIDEO_CTL is headed `[section(wired_proc, wired_data)]'; the
  others are in the default sections.

  The data block, 8 bytes, zero:

    +0x0  color2_owner3      the process that holds the DN570's display
    +0x2  color2_owner2      the process that holds the DN580's display
    +0x4  color2_associated  COLOR2_$ASSOC ran
    (the map's segment ends 3 bytes after the boolean: padding)

  The routines live in one fragment file each (color2/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color2;

%include 'base/base.ins.pas';
%if gpu_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mst/mst.ins.pas';
%include 'smd/smd.ins.pas';
%include 'tpad/tpad.ins.pas';
%include 'suma/suma.ins.pas';
%include 'kbd/kbd.ins.pas';
%include 'term/term.ins.pas';
%include 'color/color.ins.pas';
%include 'color2/color2.ins.pas';
%include 'smd/smd_internal.ins.pas';

{ TODO(sau) the SAU6 COLOR2 code

  The module's code below is the SAU5's.  tools/sau_catalog.py finds
  COLOR2_$VIDEO_CTL, COLOR2_$ASSOC, COLOR2_$LOAD_CRSR, COLOR2_$BUSY_WAIT
  and COLOR2_$INT_DECODE different on the SAU6 (its .TEXT segment
  0x4E4 bytes against the SAU5's 0x458), and the SAU5's
  COLOR2_$INT_INIT calls COLOR_ASM's COLOR_$VECTOR_INIT, which the
  SAU6 (no COLOR module) does not have. }

var
  color2_owner3: pinteger;                      { +0x0 }
  color2_owner2: pinteger;                      { +0x2 }
  color2_associated: boolean;                   { +0x4 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color2_$video_ctl;
  color2_$cold_init;
  color2_$int_init;
  color2_$assoc;
  color2_$dissoc;
  color2_$shutdown;
  color2_$load_crsr;
  color2_$busy_wait;
  color2_$get_ec;
  color2_$enable_gpu_int;
  color2_$disable_gpu_int;

{ ---- WIRED_PROC ---- }
%include 'color2/video_ctl.pas';            { COLOR2_$VIDEO_CTL }

{ ---- .TEXT ---- }
%include 'color2/cold_init.pas';            { COLOR2_$COLD_INIT }
%include 'color2/int_init.pas';             { COLOR2_$INT_INIT }
%include 'color2/assoc.pas';                { COLOR2_$ASSOC }
%include 'color2/dissoc.pas';               { COLOR2_$DISSOC }
%include 'color2/shutdown.pas';             { COLOR2_$SHUTDOWN }
%include 'color2/load_crsr.pas';            { COLOR2_$LOAD_CRSR }
%include 'color2/busy_wait.pas';            { COLOR2_$BUSY_WAIT }
%include 'color2/get_ec.pas';               { COLOR2_$GET_EC }
%include 'color2/enable_gpu_int.pas';       { COLOR2_$ENABLE_GPU_INT }
%include 'color2/disable_gpu_int.pas';      { COLOR2_$DISABLE_GPU_INT }
%endif
