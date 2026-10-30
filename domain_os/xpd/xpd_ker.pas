{ xpd/xpd_ker.pas - the XPD_KER module, XPD's register and FP access.

  One compilation unit, one code segment, no data: the map's XPD_KER
  code segment in .TEXT (0x420 bytes), XPD_$GET_REGISTERS ..
  XPD_$PUT_FP_INT, one fragment file each.  The heading names no
  section.

  Build: dpc -I domain_os domain_os/xpd/xpd_ker.pas.  Check:
  tools/pascal_check.sh.
}
module xpd_ker;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'proc2/proc2_data.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'peb/peb.ins.pas';
%include 'fp/fp.ins.pas';
%include 'xpd/xpd.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  xpd_$get_registers;
  xpd_$put_registers;
  xpd_$fp_put_state;
  xpd_$fp_get_state;
  xpd_$get_fp_int;
  xpd_$put_fp_int;

{ ---- .TEXT ---- }
%include 'xpd/get_registers.pas';           { XPD_$GET_REGISTERS }
%include 'xpd/put_registers.pas';           { XPD_$PUT_REGISTERS }
%include 'xpd/fp_put_state.pas';            { XPD_$FP_PUT_STATE }
%include 'xpd/fp_get_state.pas';            { XPD_$FP_GET_STATE }
%include 'xpd/get_fp_int.pas';              { XPD_$GET_FP_INT }
%include 'xpd/put_fp_int.pas';              { XPD_$PUT_FP_INT }
