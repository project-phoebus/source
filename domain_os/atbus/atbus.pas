{ atbus/atbus.pas - the second ATBUS_ module: the AT bus's interrupts and
  address translation.

  Image addresses:
    sau7  0x3C427B38  ATBUS_ data (WIRED_DATA, 0xA0 bytes)
    sau8  0x03C241E8  ATBUS_ data (WIRED_DATA, 0xA0 bytes)
    sau9  0x3C4255C8  ATBUS_ data (WIRED_DATA, 0xF8 bytes)

  One compilation unit, named ATBUS_ like the system bus's
  (sysbus/atbus_.pas), whose segments follow that unit's in the SAU9's
  map: a code segment in WIRED_PROC (0x2CC bytes: ATBUS_$UNDEF_INT ..
  ATBUS_$XLATE_IOVA), one in OS_INIT_PROC (0x4C bytes: ATBUS_$INIT),
  and a data segment in WIRED_DATA (248 bytes).  The data are module
  variables several routines share, so the heading names the sections
  that hold them (the LOG_ form, log/log.pas), and ATBUS_$INIT is
  headed `[section(os_init_proc, os_init_data)]'.

  Present on the SAUs whose map has the ATBUS_$ routines, the part
  atbus_routines (base/config.ins.pas: SAU7..SAU9), empty elsewhere.

  With `atbus_pics' (the SAU7's and SAU8's form) the module drives the
  AT bus's two interrupt controllers itself, ATBUS_$INT dispatching
  their vectors; its block holds only ATBUS_$INTLEV_VEC and
  ATBUS_$INT_VEC.  The SAU9's form is described here.

  On the SAU9 an AT bus interrupt (0..15) reaches the system bus on one
  of its levels 1..3 (vectors 16#A1..16#A3, sysbus/sysbus.ins.pas), the
  MMU's interrupt mask register selecting which of the level's
  interrupts it is (mmu/mmu.ins.pas); the AT bus interrupt's handler is
  the level's.  The block, 248 bytes:

    +0x00  atbus_sysbus_ids   the three levels' interrupt ids, the
                              vectors 16#A1, 16#A2, 16#A3
    +0x0C  unused_0c          4 bytes nothing addresses, zero
    +0x10  atbus_imr_select   each interrupt's select value (0..3)
    +0x30  atbus_irq_level    each interrupt's level (1..3, 0 none)
    +0x50  atbus_$intlev_vec  0, 1, 3, 2, 4..15 (map symbol)
    +0x70  atbus_$int_vec     sixteen entries, each ATBUS_$UNDEF_INT and
                              nil (map symbol)
    +0xF0  atbus_level_irq    the interrupt defined on each level, all
                              atbus_$no_irq
  The variables are in the block's order; the last word, +0xF6, is the
  block rounded to a longword.

  Check: tools/pascal_check.sh.
}
module atbus_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'sysbus/sysbus.ins.pas';
%include 'atbus/atbus.ins.pas';

%if atbus_routines %then

%if atbus_pics %then
{ The controller-pair form (`atbus_pics'; the SAU7's and SAU8's ATBUS_
  segments: 0x23C bytes in WIRED_PROC, ATBUS_$INT first, 0x84 in
  OS_INIT_PROC, and a 0xA0-byte data segment of the two map variables
  alone). }
define
  atbus_$int;
  atbus_$undef_int;
  atbus_$define_int;
  atbus_$enable_device;
  atbus_$disable_device;
  atbus_$device_interrupting;
  atbus_$clear_pending;
  atbus_$xlate_iova;
  atbus_$init;
  atbus_$intlev_vec := [0, 1, 3, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
                                          { +0x00 }
  atbus_$int_vec := [16 of [handler := addr(atbus_$undef_int)]];
                                          { +0x20 }

{ ---- WIRED_PROC ---- }
%include 'atbus/int.pas';                 { ATBUS_$INT                 }
%include 'atbus/undef_int.pas';           { ATBUS_$UNDEF_INT           }
%include 'atbus/define_int.pas';          { ATBUS_$DEFINE_INT          }
%include 'atbus/enable_device.pas';       { ATBUS_$ENABLE_DEVICE       }
%include 'atbus/disable_device.pas';      { ATBUS_$DISABLE_DEVICE      }
%include 'atbus/device_interrupting.pas'; { ATBUS_$DEVICE_INTERRUPTING }
%include 'atbus/clear_pending.pas';       { ATBUS_$CLEAR_PENDING       }
%include 'atbus/xlate_iova.pas';          { ATBUS_$XLATE_IOVA          }

{ ---- OS_INIT_PROC ---- }
%include 'atbus/init.pas';                { ATBUS_$INIT                }
%else
var
  atbus_sysbus_ids: array[1..atbus_$n_levels] of io_$int_id_t :=
    [[vector := 16#A1], [vector := 16#A2], [vector := 16#A3]];
                                          { +0x00 }
  unused_0c: integer32;                   { +0x0C: stand-in }
  atbus_imr_select: array[0..atbus_$max_irq] of mmu_$imr_select_t :=
    [0, 0, 0, 0, 1, 2, 3, 0, 0, 1, 2, 3, 0, 0, 2, 3];
                                          { +0x10 }
  atbus_irq_level: array[0..atbus_$max_irq] of atbus_$level_t :=
    [0, 0, 0, 1, 1, 1, 1, 2, 0, 2, 2, 2, 3, 0, 3, 3];
                                          { +0x30 }

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order. }
define
  atbus_$undef_int;
  atbus_$define_int;
  atbus_$enable_device;
  atbus_$disable_device;
  atbus_$device_interrupting;
  atbus_$clear_pending;
  atbus_$xlate_iova;
  atbus_$init;
  atbus_$intlev_vec := [0, 1, 3, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
                                          { +0x50 }
  atbus_$int_vec := [16 of [handler := addr(atbus_$undef_int)]];
                                          { +0x70 }

var
  atbus_level_irq: array[1..atbus_$n_levels] of pinteger :=
    [atbus_$n_levels of atbus_$no_irq];   { +0xF0 }

{ ---- WIRED_PROC ---- }
%include 'atbus/undef_int.pas';           { ATBUS_$UNDEF_INT           }
%include 'atbus/define_int.pas';          { ATBUS_$DEFINE_INT          }
%include 'atbus/enable_device.pas';       { ATBUS_$ENABLE_DEVICE       }
%include 'atbus/disable_device.pas';      { ATBUS_$DISABLE_DEVICE      }
%include 'atbus/device_interrupting.pas'; { ATBUS_$DEVICE_INTERRUPTING }
%include 'atbus/clear_pending.pas';       { ATBUS_$CLEAR_PENDING       }
%include 'atbus/xlate_iova.pas';          { ATBUS_$XLATE_IOVA          }

{ ---- OS_INIT_PROC ---- }
%include 'atbus/init.pas';                { ATBUS_$INIT                }

%endif
%endif
