{ color6/color6.pas - the COLOR6 module, the Matrox color display
  board's driver.

  Image addresses:
    sau7  0x3C435A54  COLOR6 data (WIRED_DATA, 0x18 bytes)
    sau7  0x3C440FF4  COLOR6 data (OS_INIT_DATA, 0x8 bytes)
    sau7  0x3C4ADC2C  COLOR6 data (.DATA, 0x1F0 bytes)

  With the driver (`color6_driver', base/config.ins.pas: the SAU7): one
  compilation unit in three code sections and three data sections.  The
  map's COLOR6 code segments are in OS_INIT_PROC (0x2A8 bytes:
  COLOR6_$IOINIT, COLOR6_$INSTALL_DISP), .TEXT (0x618 bytes:
  COLOR6_$CLEAR_SCREEN .. COLOR6_$DISPLAY_LOGO and three module-local
  routines) and COLOR6_WIRED_PROC (the map's `COLOR6_WIRED_PRO', cut at
  16 characters; 0x4E0 bytes: COLOR6_$START_WIRED_PROC ..
  COLOR6_$END_WIRED_PROC and six module-local routines); its data
  segments in WIRED_DATA (the wired routines' statics: two spin locks and
  two delays), OS_INIT_DATA (COLOR6_$IOINIT's and COLOR6_$INSTALL_DISP's
  statics) and .DATA (the module's variables, from COLOR6_$ASID_MAP).
  The OS_INIT_PROC routines are headed `[section(os_init_proc,
  os_init_data)]', the wired ones `[section(color6_wired_proc,
  wired_data)]', the .TEXT ones nothing.

  Not part of the module: the descriptors with the overlay section
  COLOR6_$WIRED_DATA (color6/color6_dcte.pas).

  Without the driver (every SAU but the SAU7) the maps have no COLOR6
  module, only the empty sections COLOR6_WIRED_PRO, COLOR6_$WIRED_DA and
  COLOR6_END_DATA, and the file compiles to nothing.

  The routines live in one fragment file each (color6/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module color6;

%include 'base/base.ins.pas';
%if color6_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'smd/smd.ins.pas';
%include 'color6/color6.ins.pas';

{ The module's variables, in the order of the .DATA block:
  COLOR6_$ASID_MAP (map symbol, defined here; ref 7.2.1, Method 1), each
  address space's mapping of the register pages; what the first unit's
  COLOR6_$IOINIT copies of its state for the routines that use the
  board's objects (the special object's and the display memory's UIDs);
  4 bytes nothing addresses, -1 in the image, the place of COLOR4's
  position COLOR4_$REL_DISP passes (COLOR6_$REL_DISP is empty); the
  display memory's and the register pages' addresses from the first
  unit's requests; the special segment; and whether a second unit was
  found. }
var
  color6_$asid_map: define array[proc1_$asid_t] of color6_$asid_map_t;
                                                      { +0x000 }
  color6_special_uid: uid_$t;                         { +0x1D0 }
  color6_display_uid: uid_$t;                         { +0x1D8 }
  color6_no_pos: smd_$pos_t := [line := -1, column := -1];  { +0x1E0 }
  color6_memory: integer32;                           { +0x1E4 }
  color6_regs: color6_$regs_ptr_t;                    { +0x1E8 }
  color6_special_seg: pinteger;                       { +0x1EC }
  color6_shared: boolean;                             { +0x1EE }

{ TODO(pascal) frames larger than the declared locals

  The SAU7 image's frames are larger than dpc's layout of the routines'
  declared locals in COLOR6_$IOINIT and color6_probe, COLOR6_$INSTALL_DISP,
  COLOR6_$MAP_DISP, COLOR6_$UNMAP_DISP, COLOR6_$SET_CRS_PAT and
  COLOR6_$DISPLAY_LOGO (4 to 16 bytes no instruction addresses); the
  other display drivers' copies of these routines give no use for the
  bytes.  The stand-ins are not declared. }

{ The wired module-local routines the earlier sections call. }
function color6_swap16(in w: univ color6_$bytes2_t): pinteger;
  forward; internal;
function color6_get_page(regs: color6_$regs_ptr_t): color6_$byte_t;
  forward; internal;
procedure color6_set_page(regs: color6_$regs_ptr_t; page: color6_$byte_t);
  forward; internal;
function color6_wait_ready(regs: color6_$regs_ptr_t): boolean;
  forward; internal;

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  color6_$ioinit;
  color6_$install_disp;
  color6_$clear_screen;
  color6_$video_ctl;
  color6_$rel_disp;
  color6_$map_disp;
  color6_$unmap_disp;
  color6_$set_crs_pat;
  color6_$assoc;
  color6_$dissoc;
  color6_$device_info;
  color6_$display_logo;
  color6_$start_wired_proc;
  color6_$busy_wait;
  color6_$xor_cursor;
  color6_$blink_cursor;
  color6_$putc;
  color6_$lock_display;
  color6_$end_wired_proc;

{ ---- OS_INIT_PROC ---- }
%include 'color6/ioinit.pas';                { COLOR6_$IOINIT, nested
                                               color6_probe           }
%include 'color6/install_disp.pas';          { COLOR6_$INSTALL_DISP   }

{ ---- .TEXT ---- }
%include 'color6/swap32.pas';                { color6_swap32          }
%include 'color6/clear_screen.pas';          { COLOR6_$CLEAR_SCREEN   }
%include 'color6/video_ctl.pas';             { COLOR6_$VIDEO_CTL      }
%include 'color6/send_cursor.pas';           { color6_send_cursor     }
%include 'color6/rel_disp.pas';              { COLOR6_$REL_DISP       }
%include 'color6/map_disp.pas';              { COLOR6_$MAP_DISP       }
%include 'color6/unmap_disp.pas';            { COLOR6_$UNMAP_DISP     }
%include 'color6/set_crs_pat.pas';           { COLOR6_$SET_CRS_PAT    }
%include 'color6/release.pas';               { color6_release         }
%include 'color6/assoc.pas';                 { COLOR6_$ASSOC          }
%include 'color6/dissoc.pas';                { COLOR6_$DISSOC         }
%include 'color6/device_info.pas';           { COLOR6_$DEVICE_INFO    }
%include 'color6/display_logo.pas';          { COLOR6_$DISPLAY_LOGO   }

{ ---- COLOR6_WIRED_PROC ---- }
%include 'color6/start_wired_proc.pas';      { COLOR6_$START_WIRED_PROC }
%include 'color6/swap16.pas';                { color6_swap16          }
%include 'color6/get_page.pas';              { color6_get_page        }
%include 'color6/set_page.pas';              { color6_set_page        }
%include 'color6/wait_ready.pas';            { color6_wait_ready      }
%include 'color6/fifo_count.pas';            { color6_fifo_count      }
%include 'color6/drain_fifo.pas';            { color6_drain_fifo      }
%include 'color6/busy_wait.pas';             { COLOR6_$BUSY_WAIT      }
%include 'color6/wait_idle.pas';             { color6_wait_idle       }
%include 'color6/xor_cursor.pas';            { COLOR6_$XOR_CURSOR     }
%include 'color6/blink_cursor.pas';          { COLOR6_$BLINK_CURSOR   }
%include 'color6/putc.pas';                  { COLOR6_$PUTC           }
%include 'color6/lock_display.pas';          { COLOR6_$LOCK_DISPLAY   }
%include 'color6/end_wired_proc.pas';        { COLOR6_$END_WIRED_PROC }
%endif
