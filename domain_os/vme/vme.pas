{ vme/vme.pas - the VME_ module, the VME bus's interrupt routines.

  Image addresses:
    sau5  0x00E236B0  VME_ data (WIRED_DATA, 0xD8 bytes)
    sau6  0x78025464  VME_ data (WIRED_DATA, 0x40 bytes)

  One compilation unit: on the SAU5 the map's VME_ code segments in
  WIRED_PROC (0x304 bytes: VME_$UNDEF_INT .. VME_$SAVE_VME,
  MBUS_$ENABLE_DEV, MBUS_$DISABLE_DEV) and OS_INIT_PROC (0xAC bytes:
  VME_$INIT), and its data segment in WIRED_DATA (0xD8 bytes).  The two
  MBUS_ routines are its fragments (mbus/enable_dev.pas,
  mbus/disable_dev.pas).

  The map's VME_ASM data segment (0xC bytes, VME_$SPURIOUS_INT) is hand
  assembly (vme/sau5/vme_asm.s).  The module is present with the part
  vme_bus (base/config.ins.pas), empty elsewhere.

  With `vme_vectored_ints' (the SAU6) the module is the turbo boards'
  form: the map's VME_ code segments in WIRED_PROC (0x84 bytes:
  VME_$INT, VME_$DEFINE_USERINT, VME_$UNDEF_INT) and OS_INIT_PROC (0x48
  bytes: VME_$INIT), and its data segment (0x40 bytes: VME_$USER_VEC,
  eight entries, each VME_$UNDEF_INT and nil).  Its VME_ASM data
  segment (0x4C bytes: VME_$SAVE_VME and VME_$SAVE) is hand assembly,
  vme/sau6/vme_asm.s.

  The heading names the code and data sections that hold the block (the
  LOG_ form, log/log.pas); VME_$INIT is headed `[section(os_init_proc,
  os_init_data)]'.

  The block, 0xD8 bytes:

    +0x00  vme_$save      0x18 bytes, zero (VME_$SAVE_VME fills it)
    +0x18  vme_$user_vec  sixteen entries, each VME_$UNDEF_INT and nil
    +0x98  vme_$int_vec   eight entries, each VME_$UNDEF_INT and nil

  Check: tools/pascal_check.sh.
}
module vme_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'log/log.ins.pas';
%include 'io/io.ins.pas';
%include 'mbus/mbus.ins.pas';
%include 'vme/vme.ins.pas';
%include 'gpu/gpu.ins.pas';

%if vme_bus %then

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order. }
%if vme_vectored_ints %then
define
  vme_$int;
  vme_$define_userint;
  vme_$undef_int;
  vme_$init;
  vme_$user_vec := [8 of [handler := addr(vme_$undef_int)]];
                                          { +0x00 }

{ ---- WIRED_PROC ---- }
%include 'vme/int.pas';                   { VME_$INT            }
%include 'vme/define_userint.pas';        { VME_$DEFINE_USERINT }
%include 'vme/undef_int.pas';             { VME_$UNDEF_INT      }

{ ---- OS_INIT_PROC ---- }
%include 'vme/init.pas';                  { VME_$INIT           }
%else
define
  vme_$undef_int;
  vme_$define_int;
  vme_$int;
  vme_$user_int;
  vme_$err_int;
  vme_$define_userint;
  vme_$save_vme;
  mbus_$enable_dev;
  mbus_$disable_dev;
  vme_$init;
  vme_$save;                              { +0x00 }
  vme_$user_vec := [16 of [handler := addr(vme_$undef_int)]];
                                          { +0x18 }
  vme_$int_vec := [8 of [handler := addr(vme_$undef_int)]];
                                          { +0x98 }

{ ---- WIRED_PROC ---- }
%include 'vme/undef_int.pas';             { VME_$UNDEF_INT      }
%include 'vme/define_int.pas';            { VME_$DEFINE_INT     }
%include 'vme/int.pas';                   { VME_$INT            }
%include 'vme/user_int.pas';              { VME_$USER_INT       }
%include 'vme/err_int.pas';               { VME_$ERR_INT        }
%include 'vme/define_userint.pas';        { VME_$DEFINE_USERINT }
%include 'vme/save_vme.pas';              { VME_$SAVE_VME       }
%include 'mbus/enable_dev.pas';           { MBUS_$ENABLE_DEV    }
%include 'mbus/disable_dev.pas';          { MBUS_$DISABLE_DEV   }

{ ---- OS_INIT_PROC ---- }
%include 'vme/init.pas';                  { VME_$INIT           }
%endif

%endif
