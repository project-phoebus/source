{ color7/color7.pas - the COLOR7 module, the coyote color display's
  driver.

  Image addresses:
    sau7  0x3C435D94  COLOR7 data (WIRED_DATA, 0x4 bytes)
    sau7  0x3C44100C  COLOR7 data (OS_INIT_DATA, 0x2E0 bytes)
    sau7  0x3C4ADE30  COLOR7 data (.DATA, 0x4 bytes)
    sau7  0x3C4BA6D4  COLOR7_STATIC overlay (0x10 bytes)

  With the driver (`color7_driver', base/config.ins.pas: the SAU7): one
  compilation unit in three code sections and three data sections.  The
  map's COLOR7 code segments are in OS_INIT_PROC (0xD00 bytes:
  COLOR7_$IOINIT, COLOR7_$COLD_INIT), .TEXT (0x318 bytes:
  COLOR7_$VIDEO_CTL .. COLOR7_$LOAD_CRSR) and COLOR7_WIRED_PROC (the
  map's `COLOR7_WIRED_PRO', cut at 16 characters; 0x734 bytes:
  COLOR7_$START_WIRED_PROC .. COLOR7_$END_WIRED_PROC with two
  module-local routines); its data segments in OS_INIT_DATA
  (COLOR7_$IOINIT's tables, its statics), WIRED_DATA and .DATA (4 zero
  bytes each, no object of the module's).  The module's variable is in
  the overlay section COLOR7_STATIC (ref 3.14), reached at its absolute
  address.  The OS_INIT_PROC routines are headed `[section(os_init_proc,
  os_init_data)]', the wired ones `[section(color7_wired_proc,
  wired_data)]', the .TEXT ones nothing.

  Not part of the module: the descriptor with the overlay sections
  COLOR7_$WIRED_DATA and COLOR7_END_DATA (color7/color7_dcte.pas).

  Without the driver (every SAU but the SAU7): the map's COLOR7 code
  segment (4 bytes) in COLOR7_WIRED_PROC holds COLOR7_$WORTHLESS alone,
  an empty procedure, and the module has no data.  The routine is
  headed `[section(color7_wired_proc, color7_$wired_data)]'.

  The routines live in one fragment file each (color7/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color7;

%include 'base/base.ins.pas';
%if color7_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'peb/peb.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'smd/smd.ins.pas';
%include 'color7/color7.ins.pas';

{ The driver's state, the variable named after its overlay section
  (ring/ringlog.ins.pas's form), with the image's bytes: the registers'
  address, the lock free, no cursor loaded, no owner, the configuration
  not known until COLOR7_$IOINIT. }
var (color7_static)
  color7_static: color7_$static_t :=
    [regs := color7_$regs_ptr_t(color7_$regs_va), lock := 0, cursor := -1,
     owner := 0, asid := 0, config_13 := false, config_12 := false];

{ TODO(pascal) the WIRED_DATA and .DATA blocks and the A5 loads into them

  The map's WIRED_DATA and .DATA blocks of COLOR7 are 4 zero bytes
  each, and nothing reads or writes them: no object of the source this
  module can name.  COLOR7_$ASSOC_CSRS, COLOR7_$DISSOC, COLOR7_$PUTC,
  COLOR7_$DISPLAY_LOGO, COLOR7_$SHUTDOWN and COLOR7_$MAP_DISPLAY_MEMORY
  (.TEXT), and COLOR7_$BLINK_CURSOR, COLOR7_$BUSY_WAIT and COLOR7_$LITES
  (wired), load A5 with their block's end and use it for nothing;
  COLOR7_$LOAD_CRSR and COLOR7_$COLD_INIT load their block's address
  into A0 and use it for nothing.  The same open point as
  proc2/proc2.pas's.  dpc lays out no such blocks and loads no A5 for a
  routine that does not use its data.  Until it is settled the module
  declares nothing for them. }

{ TODO(pascal) frames larger than the declared locals

  The SAU7 image's frames are larger than the declared locals' layout
  in COLOR7_$DISPLAY_LOGO (8 bytes), COLOR7_$XOR_CURSOR (8 bytes) and
  COLOR7_$LITES (4 bytes), bytes no instruction addresses; no other
  SAU has these routines to give a use for them.  The stand-ins are not
  declared. }

{ The wired module-local routines the earlier sections call. }
procedure color7_wait_idle; forward; internal;
procedure color7_write_reg(reg: integer32; offset: integer32;
                           value: integer32);
  forward; internal;

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color7_$ioinit;
  color7_$cold_init;
  color7_$video_ctl;
  color7_$clear_screen;
  color7_$map_display_memory;
  color7_$assoc_csrs;
  color7_$dissoc;
  color7_$putc;
  color7_$display_logo;
  color7_$shutdown;
  color7_$load_crsr;
  color7_$start_wired_proc;
  color7_$copy_font_md_hdm;
  color7_$lock_display;
  color7_$xor_cursor;
  color7_$blink_cursor;
  color7_$busy_wait;
  color7_$lites;
  color7_$end_wired_proc;

{ ---- OS_INIT_PROC ---- }
%include 'color7/ioinit.pas';                { COLOR7_$IOINIT              }
%include 'color7/cold_init.pas';             { COLOR7_$COLD_INIT           }

{ ---- .TEXT ---- }
%include 'color7/video_ctl.pas';             { COLOR7_$VIDEO_CTL           }
%include 'color7/clear_screen.pas';          { COLOR7_$CLEAR_SCREEN        }
%include 'color7/map_display_memory.pas';    { COLOR7_$MAP_DISPLAY_MEMORY  }
%include 'color7/assoc_csrs.pas';            { COLOR7_$ASSOC_CSRS          }
%include 'color7/dissoc.pas';                { COLOR7_$DISSOC              }
%include 'color7/putc.pas';                  { COLOR7_$PUTC                }
%include 'color7/display_logo.pas';          { COLOR7_$DISPLAY_LOGO        }
%include 'color7/shutdown.pas';              { COLOR7_$SHUTDOWN            }
%include 'color7/load_crsr.pas';             { COLOR7_$LOAD_CRSR           }

{ ---- COLOR7_WIRED_PROC ---- }
%include 'color7/start_wired_proc.pas';      { COLOR7_$START_WIRED_PROC    }
%include 'color7/wait_idle.pas';             { color7_wait_idle            }
%include 'color7/write_reg.pas';             { color7_write_reg            }
%include 'color7/copy_font_md_hdm.pas';      { COLOR7_$COPY_FONT_MD_HDM    }
%include 'color7/lock_display.pas';          { COLOR7_$LOCK_DISPLAY        }
%include 'color7/xor_cursor.pas';            { COLOR7_$XOR_CURSOR          }
%include 'color7/blink_cursor.pas';          { COLOR7_$BLINK_CURSOR        }
%include 'color7/busy_wait.pas';             { COLOR7_$BUSY_WAIT           }
%include 'color7/lites.pas';                 { COLOR7_$LITES               }
%include 'color7/end_wired_proc.pas';        { COLOR7_$END_WIRED_PROC      }
%else
%include 'color7/color7.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color7_$worthless;

{ ---- COLOR7_WIRED_PROC ---- }
%include 'color7/worthless.pas';             { COLOR7_$WORTHLESS           }
%endif
