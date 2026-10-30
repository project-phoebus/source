{ mmap/mmap_unwired.pas - the MMAP_UNWIRED module: MMAP_$INIT and
  MMAP_$REMOTE_POOL.

  One compilation unit, two code sections, no data: the map's
  MMAP_UNWIRED code segments in OS_INIT_PROC (0x278 bytes:
  mmu_$vtop_or_crash, MMAP_$INIT) and .TEXT (0xC bytes:
  MMAP_$REMOTE_POOL).

  The heading: `module mmap_unwired;'; MMAP_$INIT and the module-local
  mmu_$vtop_or_crash (mmu/vtop_or_crash.pas) are headed
  `[section(os_init_proc, os_init_data)]'.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/mmap/mmap_unwired.pas.  Check: tools/pascal_check.sh.
}
module mmap_unwired;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'dump/dump.ins.pas';
%include 'mmap/mmap.ins.pas';

define
  mmap_$init;
  mmap_$remote_pool;

{ ---- OS_INIT_PROC ---- }
%include 'mmu/vtop_or_crash.pas';        { mmu_$vtop_or_crash }
%include 'mmap/init.pas';                { MMAP_$INIT }

{ ---- .TEXT ---- }
%include 'mmap/remote_pool.pas';         { MMAP_$REMOTE_POOL }
