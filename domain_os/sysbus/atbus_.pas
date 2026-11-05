{ sysbus/atbus_.pas - the ATBUS_ module: the system bus's interrupt
  routines and set-up.

  Image addresses:
    sau2  0x00E22904  ATBUS_ data (WIRED_DATA, 0x2C bytes)
    sau3  0x00E218D8  ATBUS_ data (WIRED_DATA, 0x2C bytes)
    sau4  0x0F824BB4  ATBUS_ data (WIRED_DATA, 0x100 bytes)
    sau6  0x78025280  ATBUS_ data (WIRED_DATA, 0x1E4 bytes)
    sau9  0x3C425548  ATBUS_ data (WIRED_DATA, 0x80 bytes)

  One compilation unit, `module atbus_, wired_proc, wired_data;': the
  map's ATBUS_ code segment in WIRED_PROC and its data segment in
  WIRED_DATA.  Its data are module variables the routines share, so
  the heading names the sections that hold them (the LOG_ form,
  log/log.pas); every routine is in WIRED_PROC, and the fragments carry
  that section's attribute too.

  Two forms:
  - with `sysbus_int_vec' (the SAU9's, base/config.ins.pas): SYSBUS_$INT
    .. SYSBUS_$INIT, the routines of the system bus's sixteen
    interrupt levels (0x320 bytes on the SAU9; the four device
    routines with `util_pic'), and a block of 128 bytes, the map's
    SYSBUS_$INT_VEC, all zero in the image; with `sysbus_vectors_90'
    (the SAU4's) 32 levels on two ranges of vectors (0x160 bytes) and a
    block of 256 bytes; with `sysbus_vectors_88' (the SAU6's) 32 levels
    on two other ranges, each with a second handler (0x1DC bytes), and
    a block of 0x1E4 bytes: SYSBUS_$DUP_VEC, eight 12-byte entries,
    SYSBUS_$INT_VEC's 32 12-byte entries at +0x60 and the next free
    entry of SYSBUS_$DUP_VEC, a word at +0x1E0, all zero in the image;
  - without it (the SAU2's): DISK_INTERRUPT, RING_INTERRUPT (from disk/
    and ring/), SYSBUS_$INIT and SYSBUS_$DEFINE_INT (0x118 bytes), and a
    block of 44 bytes, all zero in the image, which SYSBUS_$INIT fills:
    a do_io routine, a DCTE and a dinit pointer for controller types 2
    (ring), 1 (floppy) and 0 (Winchester), at +0x00, +0x10 and +0x20;
    the longwords at +0x0C and +0x1C are stand-ins (TODO below).
    Without `winchester_config' (the SAU3) there is no DISK_INTERRUPT,
    and only the ring's slots are filled (0x84 bytes; the block is the
    same).

  The SAU5's map has no ATBUS_ segment: the body is configured out by
  `sysbus_routines'.  The SAU7..SAU9's second ATBUS_ compilation unit,
  the ATBUS_$ routines, is atbus/atbus.pas.

  Build: dpc -I domain_os domain_os/sysbus/atbus_.pas.  Check:
  tools/pascal_check.sh (which finds this file by its module heading).
}
module atbus_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%if sysbus_routines %then
%include 'misc/crash_system.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'disk/disk.ins.pas';
%include 'flp/flp.ins.pas';               { flp_$regs_t: DISK_INTERRUPT }
%include 'ring/ring.ins.pas';
%include 'sysbus/sysbus.ins.pas';

%if sysbus_int_vec %then

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order. }
define
  sysbus_$int;
  sysbus_$undef_int;
  sysbus_$define_int;
%if util_pic %then
  sysbus_$enable_device;
  sysbus_$disable_device;
  sysbus_$device_interrupting;
  sysbus_$clear_pending;
%endif
  sysbus_$init;
%if sysbus_vectors_88 %then
  sysbus_$dup_vec;                        { +0x00 }
  sysbus_$int_vec;                        { +0x60 }

var
  dup_next: integer;                      { +0x1E0 }
%else
  sysbus_$int_vec;                        { +0x00 }
%endif

{ ---- WIRED_PROC ---- }
%include 'sysbus/int.pas';                { SYSBUS_$INT                 }
%include 'sysbus/undef_int.pas';          { SYSBUS_$UNDEF_INT           }
%include 'sysbus/define_int.pas';         { SYSBUS_$DEFINE_INT          }
%if util_pic %then
%include 'sysbus/enable_device.pas';      { SYSBUS_$ENABLE_DEVICE       }
%include 'sysbus/disable_device.pas';     { SYSBUS_$DISABLE_DEVICE      }
%include 'sysbus/device_interrupting.pas';
                                          { SYSBUS_$DEVICE_INTERRUPTING }
%include 'sysbus/clear_pending.pas';      { SYSBUS_$CLEAR_PENDING       }
%endif
%include 'sysbus/init.pas';               { SYSBUS_$INIT                }

%else

{ TODO(pascal) the block's two longwords nothing addresses

  +0x0C and +0x1C (reserved_0c, reserved_1c) are read and written by no
  routine of the image.  As three 12-byte records aligned to 8 they
  would come out at the same offsets (sysbus/README.md), and dpc
  does not 8-align records.  Stand-ins keep the offsets. }

var
  type2_do_io: io_$do_io_t;               { +0x00 }
  type2_dcte: dcte_ptr_t;                 { +0x04 }
  type2_dinit: univ_ptr;                  { +0x08 }
  reserved_0c: integer32;                 { +0x0C: stand-in (TODO above) }
  type1_do_io: io_$do_io_t;               { +0x10 }
  type1_dcte: dcte_ptr_t;                 { +0x14 }
  type1_dinit: univ_ptr;                  { +0x18 }
  reserved_1c: integer32;                 { +0x1C: stand-in (TODO above) }
  type0_do_io: io_$do_io_t;               { +0x20 }
  type0_dcte: dcte_ptr_t;                 { +0x24 }
  type0_dinit: univ_ptr;                  { +0x28 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if winchester_config %then
  disk_interrupt;
%endif
  ring_interrupt;
  sysbus_$init;
  sysbus_$define_int;

{ ---- WIRED_PROC ---- }
%if winchester_config %then
%include 'disk/interrupt.pas';            { DISK_INTERRUPT     }
%endif
%include 'ring/interrupt.pas';            { RING_INTERRUPT     }
%include 'sysbus/init.pas';               { SYSBUS_$INIT       }
%include 'sysbus/define_int.pas';         { SYSBUS_$DEFINE_INT }

%endif
%endif
