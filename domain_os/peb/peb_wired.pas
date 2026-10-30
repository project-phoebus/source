{ peb/peb_wired.pas - the PEB_WIRED module, the board's wired code: the
  context switch on a touch of its page, the report of its flags and the
  process cleanup.

  Image addresses:
    sau2  0x00E84E80  PEB_WIRED data (.DATA, 0x658 bytes)

  One compilation unit: the map's PEB_WIRED code segments in .TEXT
  (0x22C bytes: PEB_$TOUCH, also PEB_$WIRED_PROC_START, and
  PEB_$GET_INFO) and in PROC2_DELETE_PRO (0x20 bytes:
  PEB_$PROC_CLEANUP), and its data segment in .DATA (0x658 bytes:
  PEB_$REGS, also PEB_$WIRED_DATA_START).  Without `peb_board'
  (base/config.ins.pas) the .TEXT segment is 0x60 bytes (PEB_$TOUCH a
  constant false, PEB_$GET_INFO), PEB_$PROC_CLEANUP is empty, and there
  is no data segment.

  The marker segment PEB_WIRED_END (4 zero bytes, PEB_$WIRED_PROC_END)
  has no Pascal; PEB_$LOAD_WCS wires the code and data the markers bound
  (peb/load_wcs.pas): "wired" at run time.

  The heading: `module peb_wired;' (the defaults).  PEB_$PROC_CLEANUP
  is headed `[section(proc2_delete_pro, proc2_delete_dat)]'.

  The data, 0x658 bytes, zero in the image: PEB_$REGS, 58 elements of
  0x1C bytes (peb/peb.ins.pas peb_$fp_state_t), from 0.

  The routines live in one fragment file each, included below in image
  order: peb/touch.pas, peb/cleanup_internal.pas, peb/proc_cleanup.pas,
  peb/get_info.pas.

  Build: dpc -I domain_os domain_os/peb/peb_wired.pas.  Check:
  tools/pascal_check.sh.
}
module peb_wired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'peb/peb.ins.pas';

{ The module's one variable, the map symbol PEB_$REGS (+0x000, zero). }
%if peb_board %then
define
  peb_$regs;
%endif

define
  peb_$touch;
  peb_$get_info;
  peb_$proc_cleanup;

{ ---- .TEXT ---- }
%include 'peb/touch.pas';                   { PEB_$TOUCH }
%if peb_board %then
%include 'peb/cleanup_internal.pas';        { peb_$cleanup_internal
                                              (.TEXT) }
%endif
%include 'peb/proc_cleanup.pas';            { PEB_$PROC_CLEANUP
                                              (PROC2_DELETE_PRO) }
%include 'peb/get_info.pas';                { PEB_$GET_INFO }
