{ color4/color4.pas - the COLOR4 module, a color display board's driver.

  Image addresses:
    sau7  0x3C435B2C  COLOR4 data (WIRED_DATA, 0x28 bytes)
    sau7  0x3C440FFC  COLOR4 data (OS_INIT_DATA, 0x10 bytes)
    sau7  0x3C4ADE1C  COLOR4 data (.DATA, 0x8 bytes)
    sau8  0x03C302D8  COLOR4 data (WIRED_DATA, 0x28 bytes)
    sau8  0x03C399A8  COLOR4 data (OS_INIT_DATA, 0x10 bytes)
    sau8  0x03C9D428  COLOR4 data (.DATA, 0x8 bytes)

  With the driver (`color4_driver', base/config.ins.pas: the SAU7 and
  SAU8): one compilation unit in three code sections and three data
  sections.  The map's COLOR4 code segments are in OS_INIT_PROC (0x238
  bytes: COLOR4_$IOINIT, COLOR4_$INSTALL_DISP_MEM), .TEXT (0x33C bytes:
  COLOR4_$CLEAR_SCREEN .. COLOR4_$SET_COLOR_TABLE) and COLOR4_WIRED_PROC
  (the map's `COLOR4_WIRED_PRO', cut at 16 characters; 0x650 bytes:
  COLOR4_$COPY_FONT_MD_HDM .. COLOR4_$LITES); its data segments in
  WIRED_DATA (COLOR4_$LITES's tables), OS_INIT_DATA (COLOR4_$IOINIT's
  ramp) and .DATA (the position COLOR4_$REL_DISP passes, then
  COLOR4_$DEBUG).  The first two are routines' statics, the .DATA block
  the module's variables.  The OS_INIT_PROC routines are headed
  `[section(os_init_proc, os_init_data)]', the wired ones
  `[section(color4_wired_proc, wired_data)]', the .TEXT ones nothing.

  Not part of the module: the map's COLOR4_ASM (hand assembly after the
  wired routines: COLOR4_$LOAD_LUT, COLOR4_$END_WIRED_PROC;
  color4/m68k/color4_asm.s), and the descriptors with the overlay section
  COLOR4_$WIRED_DATA (color4/color4_dcte.pas).

  Without the driver (the SAU2, SAU3, SAU4, SAU5, SAU6 and SAU9): the
  map's COLOR4 code segment (4 bytes) in COLOR4_WIRED_PROC holds
  COLOR4_$WORTHLESS alone, an empty procedure, and the module has no
  data.  The routine is headed `[section(color4_wired_proc,
  color4_$wired_data)]'.

  The routines live in one fragment file each (color4/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color4;

%include 'base/base.ins.pas';
%if color4_driver %then
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
%include 'color4/color4.ins.pas';

{ The module's variables, in the order of the .DATA block: the position
  COLOR4_$REL_DISP gives SHOW_CURSOR, and COLOR4_$DEBUG (map symbol,
  defined here; ref 7.2.1, Method 1), which no compiled code reads. }
var
  color4_no_pos: smd_$pos_t := [line := -1, column := -1];  { +0x0 }
  color4_$debug: define integer32 := 0;                     { +0x4 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color4_$ioinit;
  color4_$install_disp_mem;
  color4_$clear_screen;
  color4_$video_ctl;
  color4_$rel_disp;
  color4_$map_display_memory;
  color4_$unmap_display_memory;
  color4_$assoc_csrs;
  color4_$dissoc;
  color4_$display_logo;
  color4_$set_color_table;
  color4_$copy_font_md_hdm;
  color4_$lock_display;
  color4_$xor_cursor;
  color4_$blink_cursor;
  color4_$putc;
  color4_$lites;

{ ---- OS_INIT_PROC ---- }
%include 'color4/ioinit.pas';                { COLOR4_$IOINIT               }
%include 'color4/install_disp_mem.pas';      { COLOR4_$INSTALL_DISP_MEM     }

{ ---- .TEXT ---- }
%include 'color4/clear_screen.pas';          { COLOR4_$CLEAR_SCREEN         }
%include 'color4/video_ctl.pas';             { COLOR4_$VIDEO_CTL            }
%include 'color4/rel_disp.pas';              { COLOR4_$REL_DISP             }
%include 'color4/map_display_memory.pas';    { COLOR4_$MAP_DISPLAY_MEMORY   }
%include 'color4/unmap_display_memory.pas';  { COLOR4_$UNMAP_DISPLAY_MEMORY }
%include 'color4/assoc_csrs.pas';            { COLOR4_$ASSOC_CSRS           }
%include 'color4/dissoc.pas';                { COLOR4_$DISSOC               }
%include 'color4/display_logo.pas';          { COLOR4_$DISPLAY_LOGO         }
%include 'color4/set_color_table.pas';       { COLOR4_$SET_COLOR_TABLE      }

{ ---- COLOR4_WIRED_PROC ---- }
%include 'color4/copy_font_md_hdm.pas';      { COLOR4_$COPY_FONT_MD_HDM     }
%include 'color4/lock_display.pas';          { COLOR4_$LOCK_DISPLAY         }
%include 'color4/xor_cursor.pas';            { COLOR4_$XOR_CURSOR           }
%include 'color4/blink_cursor.pas';          { COLOR4_$BLINK_CURSOR         }
%include 'color4/putc.pas';                  { COLOR4_$PUTC                 }
%include 'color4/lites.pas';                 { COLOR4_$LITES                }
%else
%include 'color4/color4.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color4_$worthless;

{ ---- COLOR4_WIRED_PROC ---- }
%include 'color4/worthless.pas';             { COLOR4_$WORTHLESS            }
%endif
