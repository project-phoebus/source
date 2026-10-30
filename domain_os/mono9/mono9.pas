{ mono9/mono9.pas - the MONO9 module, the DN2500 monochrome display's
  routines for the display driver.

  Image addresses:
    sau9  0x3C433488  MONO9 data (WIRED_DATA, 0x4 bytes)

  One compilation unit, in three code sections and one data section: the
  map's MONO9 code segments in WIRED_PROC (0x88 bytes:
  MONO9_$LOCK_DISPLAY, MONO9_$BLINK_CURSOR), OS_INIT_PROC (0xA0 bytes:
  MONO9_$IOINIT, MONO9_$INSTALL_DISP) and .TEXT (0x2DC bytes:
  MONO9_$COPY_FONT_MD_HDM .. MONO9_$DISPLAY_LOGO), and its data segment
  in WIRED_DATA (4 bytes, zero: MONO9_$LOCK_DISPLAY's spin lock, its
  static).

  The heading names no sections: the only data are a routine's static
  (the TTY form, tty/tty.pas).  .TEXT is the default code section; the
  WIRED_PROC routines are headed `[section(wired_proc, wired_data)]',
  the OS_INIT_PROC ones `[section(os_init_proc, os_init_data)]'.

  Not part of the module: the map's MONO9_ASM (hand assembly, its own
  segment in WIRED_DATA after this one's block: DISP_QUERY,
  MONO9_$VIDEO_CTL, MONO9_$SET_COLOR_TABLE, MONO9_$XOR_CURSOR;
  mono9/sau9/mono9_asm.s) and the descriptor with the overlay section
  MONO9_$WIRED_DATA (mono9/mono9_desc.pas).

  With the part mono9_display (base/config.ins.pas): only the SAU9's
  map has MONO9.  Elsewhere the module is empty.

  The routines are the display driver's (the SAU9's SMD_), called
  through the routine vector in MONO9_$WIRED_DATA with the descriptor's
  address first, or the descriptor's init routine.  One fragment file
  each (mono9/<name>.pas), in image order.

  Check: tools/pascal_check.sh.
}
module mono9;

%include 'base/base.ins.pas';
%if mono9_display %then
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'io/io.ins.pas';
%include 'os/os.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'smd/smd.ins.pas';
%include 'mono9/mono9.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  mono9_$lock_display;
  mono9_$blink_cursor;
  mono9_$ioinit;
  mono9_$install_disp;
  mono9_$copy_font_md_hdm;
  mono9_$clear_screen;
  mono9_$map_disp;
  mono9_$unmap_disp;
  mono9_$assoc;
  mono9_$dissoc;
  mono9_$display_logo;

{ ---- WIRED_PROC ---- }
%include 'mono9/lock_display.pas';        { MONO9_$LOCK_DISPLAY     }
%include 'mono9/blink_cursor.pas';        { MONO9_$BLINK_CURSOR     }

{ ---- OS_INIT_PROC ---- }
%include 'mono9/ioinit.pas';              { MONO9_$IOINIT           }
%include 'mono9/install_disp.pas';        { MONO9_$INSTALL_DISP     }

{ ---- .TEXT ---- }
%include 'mono9/copy_font_md_hdm.pas';    { MONO9_$COPY_FONT_MD_HDM }
%include 'mono9/clear_screen.pas';        { MONO9_$CLEAR_SCREEN     }
%include 'mono9/map_disp.pas';            { MONO9_$MAP_DISP         }
%include 'mono9/unmap_disp.pas';          { MONO9_$UNMAP_DISP       }
%include 'mono9/assoc.pas';               { MONO9_$ASSOC            }
%include 'mono9/dissoc.pas';              { MONO9_$DISSOC           }
%include 'mono9/display_logo.pas';        { MONO9_$DISPLAY_LOGO     }
%endif
