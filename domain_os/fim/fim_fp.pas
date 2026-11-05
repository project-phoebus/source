{ fim/fim_fp.pas - the FIM_FP module, the floating-point accelerator's
  exception handler.

  Image addresses:
    sau7  0x3C4AAB00  FIM_FP data (.DATA, 4 bytes)

  One compilation unit, one code segment and one data segment: the map's
  FIM_FP code segment (.TEXT, 0x1E3C bytes), FIM_$FP_INTERLUDE_HANDLER
  and its nested routines, and its data segment in .DATA (4 zero bytes).
  The routines it calls to reach the accelerator are hand assembly in
  the FIM_UNWIRED segment (fim/sau7/fpa_regs.s; fp/fp.ins.pas).

  Present on the SAUs with the floating-point accelerator, the part
  `fpa_board' (base/config.ins.pas): only the SAU7's map has the
  module.  Elsewhere the module is empty: its whole body is conditional.

  The heading names no section.

  Check: tools/pascal_check.sh.
}
module fim_fp;

{ TODO(pascal) the 4-byte data block and the A5 load into it

  FIM_FP's zero 4-byte data segment holds no object this module can
  name, and FIM_$FP_INTERLUDE_HANDLER loads A5 with its end without
  using it (as XPD's blocks, xpd/xpd.pas).  Until the cause is known the
  module declares nothing for it, and dpc loads no A5 here. }

%include 'base/base.ins.pas';
%if fpa_board %then
%include 'ec/ec.ins.pas';
%include 'fim/fim.ins.pas';
%include 'fp/fp.ins.pas';

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  fim_$fp_interlude_handler;

{ ---- .TEXT ---- }
%include 'fim/fp_interlude_handler.pas';  { FIM_$FP_INTERLUDE_HANDLER }
%endif
