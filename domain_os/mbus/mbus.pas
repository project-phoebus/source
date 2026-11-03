{ mbus/mbus.pas - the MBUS_ module, the Multibus interrupt vector.

  Image addresses:
    sau3  0x00E21854  MBUS_ data (WIRED_DATA, 0x84 bytes)
    sau5  0x00E2362C  MBUS_ data (WIRED_DATA, 0x84 bytes)

  One compilation unit, in two code sections and one data section: on
  the SAU5 the map's MBUS_ code segments in WIRED_PROC (0x70 bytes:
  MBUS_$UNDEF_INT, MBUS_$DEFINE_INT) and OS_INIT_PROC (0x74 bytes:
  MBUS_$INIT), and its MBUS_ data segment in WIRED_DATA (0x84 bytes).
  MBUS_$ENABLE_DEV and MBUS_$DISABLE_DEV are the VME_ module's
  (vme/vme.pas); their fragments are in this directory.

  Present on the SAUs whose kernel has a Multibus, the part mbus_bus
  (base/config.ins.pas): the SR10.2 maps of the SAU3..SAU6 have the
  three MBUS_ segments (WIRED_PROC 0xDC, 0xC8, 0x70, 0xB4 bytes;
  OS_INIT_PROC 0x88, 0x98, 0x74, 0x9C; data 0x84 on each), the maps of
  the SAU2 and SAU7..SAU9 none.  Elsewhere the module is empty: its
  whole body is conditional.

  Sections: the data are module variables that routines of two
  sections and two other modules use (VME_$INT, PBU_$INIT), so the
  heading names the code and data sections that hold them (log/log.pas's
  form), and MBUS_$INIT is headed `[section(os_init_proc,
  os_init_data)]'.

  The block, 0x84 bytes, all zero in the image:
    +0x00  mbus_$int_vec   sixteen handler and argument pairs, by level
    +0x80  mbus_$high_ok   boolean, set by MBUS_$INIT (rounded to a word)
    +0x82  mbus_$present   boolean, TESTPAGE's answer (rounded to a word)
  The three are declared extern in mbus/mbus.ins.pas and defined here
  (ref 7.2.2, Method 2), in the block's order.

  Check: tools/pascal_check.sh.
}
module mbus_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'mbus/mbus.ins.pas';

%if mbus_bus %then

{ TODO(sau) MBUS_$INT on the SAU4 and SAU6

  The SAU3's, SAU4's and SAU6's MBUS_ WIRED_PROC segments hold a third
  routine, MBUS_$INT (0x6E, 0x5A and 0x4E bytes), the bus's interrupt
  routine, which the SAU5's lacks (VME_$INT dispatches the Multibus's
  levels there).  The SAU3's is written (`mbus_polled_adapter',
  mbus/int.pas); the SAU4's and SAU6's are other forms (see the
  TODO(sau) in mbus/int.pas). }

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order. }
define
  mbus_$undef_int;
  mbus_$define_int;
%if mbus_polled_adapter %then
  mbus_$int;
%endif
  mbus_$init;
  mbus_$int_vec;                          { +0x00 }
  mbus_$high_ok;                          { +0x80 }
  mbus_$present;                          { +0x82 }

{ ---- WIRED_PROC ---- }
%include 'mbus/undef_int.pas';            { MBUS_$UNDEF_INT    }
%include 'mbus/define_int.pas';           { MBUS_$DEFINE_INT   }
%if mbus_polled_adapter %then
%include 'mbus/int.pas';                  { MBUS_$INT          }
%endif

{ ---- OS_INIT_PROC ---- }
%include 'mbus/init.pas';                 { MBUS_$INIT         }

%endif
