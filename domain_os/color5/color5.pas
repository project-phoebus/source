{ color5/color5.pas - the COLOR5 module, a color display board's driver.

  Image addresses:
    sau7  0x3C435BD4  COLOR5 data (WIRED_DATA, 0x20 bytes)
    sau7  0x3C4ADE24  COLOR5 data (.DATA, 0x4 bytes)
    sau8  0x03C30380  COLOR5 data (WIRED_DATA, 0x20 bytes)
    sau8  0x03C9D430  COLOR5 data (.DATA, 0x4 bytes)

  With the driver (`color5_driver', base/config.ins.pas: the SAU7 and
  SAU8): one compilation unit in three code sections and two data
  sections, COLOR4's shape (color4/color4.pas).  The map's COLOR5 code
  segments are in OS_INIT_PROC (0x2B0 bytes: COLOR5_$IOINIT,
  COLOR5_$INSTALL_DISP_MEM), .TEXT (0x340 bytes: COLOR5_$CLEAR_SCREEN ..
  COLOR5_$DISPLAY_LOGO) and COLOR5_WIRED_PROC (the map's
  `COLOR5_WIRED_PRO', cut at 16 characters; 0x6EC bytes:
  COLOR5_$COPY_FONT_MD_HDM .. COLOR5_$LIGHTS); its data segments in
  WIRED_DATA (COLOR5_$LIGHTS's columns, a static) and .DATA (the
  position COLOR5_$REL_DISP passes, the module's variable).  The
  OS_INIT_PROC routines are headed `[section(os_init_proc,
  os_init_data)]', the wired ones `[section(color5_wired_proc,
  wired_data)]', the .TEXT ones nothing.

  Not part of the module: the descriptors with the overlay section
  COLOR5_$WIRED_DATA (color5/color5_dcte.pas).  COLOR5_$START_WIRED_PROC
  and COLOR5_$END_WIRED_PROC, the bounds of the driver's wired code, are
  layout marks, not objects of this module.

  Without the driver (the SAU2, SAU3, SAU4, SAU5, SAU6 and SAU9): the
  map's COLOR5 code segment (4 bytes) in COLOR5_WIRED_PROC holds
  COLOR5_$WORTHLESS alone, an empty procedure, and the module-end
  filler, and the module has no data.  The routine is headed
  `[section(color5_wired_proc, color5_$wired_data)]'.

  The routines live in one fragment file each (color5/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color5;

%include 'base/base.ins.pas';
%if color5_driver %then
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
%include 'color5/color5.ins.pas';

{ The module's variable, the .DATA block: the position COLOR5_$REL_DISP
  gives SHOW_CURSOR. }
var
  color5_no_pos: smd_$pos_t := [line := -1, column := -1];  { +0x0 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color5_$ioinit;
  color5_$install_disp_mem;
  color5_$clear_screen;
  color5_$video_ctl;
  color5_$rel_disp;
  color5_$map_display_memory;
  color5_$unmap_display_memory;
  color5_$assoc_csrs;
  color5_$dissoc;
  color5_$display_logo;
  color5_$copy_font_md_hdm;
  color5_$lock_display;
  color5_$xor_cursor;
  color5_$blink_cursor;
  color5_$putc;
  color5_$lights;

{ ---- OS_INIT_PROC ---- }
%include 'color5/ioinit.pas';                { COLOR5_$IOINIT               }
%include 'color5/install_disp_mem.pas';      { COLOR5_$INSTALL_DISP_MEM     }

{ ---- .TEXT ---- }
%include 'color5/clear_screen.pas';          { COLOR5_$CLEAR_SCREEN         }
%include 'color5/video_ctl.pas';             { COLOR5_$VIDEO_CTL            }
%include 'color5/rel_disp.pas';              { COLOR5_$REL_DISP             }
%include 'color5/map_display_memory.pas';    { COLOR5_$MAP_DISPLAY_MEMORY   }
%include 'color5/unmap_display_memory.pas';  { COLOR5_$UNMAP_DISPLAY_MEMORY }
%include 'color5/assoc_csrs.pas';            { COLOR5_$ASSOC_CSRS           }
%include 'color5/dissoc.pas';                { COLOR5_$DISSOC               }
%include 'color5/display_logo.pas';          { COLOR5_$DISPLAY_LOGO         }

{ ---- COLOR5_WIRED_PROC ---- }
%include 'color5/copy_font_md_hdm.pas';      { COLOR5_$COPY_FONT_MD_HDM     }
%include 'color5/lock_display.pas';          { COLOR5_$LOCK_DISPLAY         }
%include 'color5/xor_cursor.pas';            { COLOR5_$XOR_CURSOR           }
%include 'color5/blink_cursor.pas';          { COLOR5_$BLINK_CURSOR         }
%include 'color5/putc.pas';                  { COLOR5_$PUTC                 }
%include 'color5/lights.pas';                { COLOR5_$LIGHTS               }
%else
%include 'color5/color5.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color5_$worthless;

{ ---- COLOR5_WIRED_PROC ---- }
%include 'color5/worthless.pas';             { COLOR5_$WORTHLESS            }
%endif
