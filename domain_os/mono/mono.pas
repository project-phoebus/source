{ mono/mono.pas - the MONO module, a monochrome display board's driver.

  Image addresses:
    sau7  0x3C435C74  MONO data (WIRED_DATA, 0x20 bytes)
    sau7  0x3C4ADE28  MONO data (.DATA, 0x8 bytes)
    sau8  0x03C30420  MONO data (WIRED_DATA, 0x20 bytes)
    sau8  0x03C9D434  MONO data (.DATA, 0x8 bytes)

  With the driver (`mono_driver', base/config.ins.pas: the SAU7 and
  SAU8): one compilation unit in three code sections and two data
  sections, COLOR4's shape (color4/color4.pas).  The map's MONO code
  segments are in OS_INIT_PROC (0x1DC bytes: MONO_$IOINIT,
  MONO_$INSTALL_DISP_MEM), .TEXT (0x32C bytes: MONO_$CLEAR_SCREEN ..
  MONO_$DISPLAY_LOGO) and MONO_WIRED_PROC (0x664 bytes:
  MONO_$COPY_FONT_MD_HDM .. MONO_$END_WIRED_PROC); its data segments in
  WIRED_DATA (MONO_$LIGHTS's columns, a static) and .DATA (the position
  MONO_$REL_DISP passes, then MONO_$DEBUG: the module's variables).  The
  OS_INIT_PROC routines are headed `[section(os_init_proc,
  os_init_data)]', the wired ones `[section(mono_wired_proc,
  wired_data)]', the .TEXT ones nothing.

  Not part of the module: the descriptors with the overlay section
  MONO_$WIRED_DATA (mono/mono_dcte.pas).

  Without the driver the module is empty: the maps of the SAUs without
  it have no MONO segment (their MONO_WIRED_PROC, MONO_$WIRED_DATA and
  MONO_END_DATA sections hold no module's bytes).

  The routines live in one fragment file each (mono/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module mono;

%include 'base/base.ins.pas';
%if mono_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'atbus/atbus.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'smd/smd.ins.pas';
%include 'mono/mono.ins.pas';

{ The module's variables, in the order of the .DATA block: the position
  MONO_$REL_DISP gives SHOW_CURSOR, and MONO_$DEBUG (map symbol, defined
  here; ref 7.2.1, Method 1), which no compiled code reads. }
var
  mono_no_pos: smd_$pos_t := [line := -1, column := -1];  { +0x0 }
  mono_$debug: define integer32 := 0;                     { +0x4 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  mono_$ioinit;
  mono_$install_disp_mem;
  mono_$clear_screen;
  mono_$video_ctl;
  mono_$rel_disp;
  mono_$map_display_memory;
  mono_$unmap_display_memory;
  mono_$assoc_csrs;
  mono_$dissoc;
  mono_$display_logo;
  mono_$copy_font_md_hdm;
  mono_$lock_display;
  mono_$xor_cursor;
  mono_$blink_cursor;
  mono_$putc;
  mono_$lights;
  mono_$end_wired_proc;

{ ---- OS_INIT_PROC ---- }
%include 'mono/ioinit.pas';                { MONO_$IOINIT               }
%include 'mono/install_disp_mem.pas';      { MONO_$INSTALL_DISP_MEM     }

{ ---- .TEXT ---- }
%include 'mono/clear_screen.pas';          { MONO_$CLEAR_SCREEN         }
%include 'mono/video_ctl.pas';             { MONO_$VIDEO_CTL            }
%include 'mono/rel_disp.pas';              { MONO_$REL_DISP             }
%include 'mono/map_display_memory.pas';    { MONO_$MAP_DISPLAY_MEMORY   }
%include 'mono/unmap_display_memory.pas';  { MONO_$UNMAP_DISPLAY_MEMORY }
%include 'mono/assoc_csrs.pas';            { MONO_$ASSOC_CSRS           }
%include 'mono/dissoc.pas';                { MONO_$DISSOC               }
%include 'mono/display_logo.pas';          { MONO_$DISPLAY_LOGO         }

{ ---- MONO_WIRED_PROC ---- }
%include 'mono/copy_font_md_hdm.pas';      { MONO_$COPY_FONT_MD_HDM     }
%include 'mono/lock_display.pas';          { MONO_$LOCK_DISPLAY         }
%include 'mono/xor_cursor.pas';            { MONO_$XOR_CURSOR           }
%include 'mono/blink_cursor.pas';          { MONO_$BLINK_CURSOR         }
%include 'mono/putc.pas';                  { MONO_$PUTC                 }
%include 'mono/lights.pas';                { MONO_$LIGHTS               }
%include 'mono/end_wired_proc.pas';        { MONO_$END_WIRED_PROC       }
%endif
