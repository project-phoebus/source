{ peb/peb_unwired.pas - the PEB_UNWIRED module, the board's set-up and
  its unwired entry points.

  Image addresses:
    sau2  0x00E8180C  PEB_UNWIRED data (.DATA, 4 bytes)
    sau9  0x3C499F90  PEB_UNWIRED data (.DATA, 4 bytes)

  One compilation unit: the map's PEB_UNWIRED code segments in
  OS_INIT_PROC (0x5F8 bytes: PEB_$INIT, PEB_$LOAD_WCS) and in .TEXT
  (0x200 bytes: PEB_$ASSOC .. PEB_$PUT_FP), and its data segment in
  .DATA (4 bytes: M68881_EXISTS, a boolean at +0, zero).  Without
  `peb_board' (base/config.ins.pas) only the OS_INIT_PROC segment, 0x1D8
  bytes on the SAU9: PEB_$INIT and PEB_$LOAD_WCS for the MC68881.
  Without `peb_setup' (the SAU4, whose map has no PEB_UNWIRED segment)
  the module compiles to nothing.

  The heading: `module peb_unwired;' (the defaults).  The OS_INIT_PROC
  routines are headed `[section(os_init_proc, os_init_data)]' and reach
  M68881_EXISTS by its address; no routine loads A5.

  The routines live in one fragment file each (peb/<name>.pas), included
  below in image order: OS_INIT_PROC first, then .TEXT.

  Build: dpc -I domain_os domain_os/peb/peb_unwired.pas.  Check:
  tools/pascal_check.sh.
}
module peb_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'ml/ml.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'dma/dma.ins.pas';
%include 'io/io.ins.pas';
%include 'sysbus/sysbus.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'mst/mst.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'fp/fp.ins.pas';
%include 'fim/fim.ins.pas';
%include 'peb/peb.ins.pas';

%if peb_setup %then
{ The module's one variable, the map symbol M68881_EXISTS (+0x0, zero). }
define
  m68881_exists;

define
  peb_$init;
  peb_$load_wcs;

%if peb_board %then
define
  peb_$assoc;
  peb_$dissoc;
  peb_$get_status;
  peb_$load_regs;
  peb_$unload_regs;
  peb_$get_fp;
  peb_$put_fp;
%endif

{ ---- OS_INIT_PROC ---- }
%include 'peb/init.pas';                    { PEB_$INIT }
%if peb_board %then
%include 'peb/write_wcs.pas';               { peb_$write_wcs }
%include 'peb/read_wcs.pas';                { peb_$read_wcs }
%endif
%include 'peb/load_wcs.pas';                { PEB_$LOAD_WCS and its nested
                                              check }

%if peb_board %then
{ ---- .TEXT ---- }
%include 'peb/assoc.pas';                   { PEB_$ASSOC }
%include 'peb/dissoc.pas';                  { PEB_$DISSOC }
%include 'peb/get_status.pas';              { PEB_$GET_STATUS }
%include 'peb/load_regs.pas';               { PEB_$LOAD_REGS }
%include 'peb/unload_regs.pas';             { PEB_$UNLOAD_REGS }
%include 'peb/get_fp.pas';                  { PEB_$GET_FP }
%include 'peb/put_fp.pas';                  { PEB_$PUT_FP }
%endif
%endif
