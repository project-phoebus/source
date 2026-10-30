{ flop/flop.pas - the FLOP_BOOT module, booting from the floppy.

  One compilation unit, one code segment, no data: the map's FLOP_BOOT
  code segment in OS_INIT_PROC (0x38C bytes), with one map symbol,
  FLOP_$BOOT, and its two nested routines before it.

  The heading names no sections; FLOP_$BOOT is headed
  `[section(os_init_proc, os_init_data)]', which its nested routines
  inherit.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/flop/flop.pas.  Check: tools/pascal_check.sh.
}
module flop_boot;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';                 { disk/disk.ins.pas needs it }
%include 'misc/crash_system.ins.pas';
%include 'disk/disk.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'mst/mst.ins.pas';
%include 'dir/dir.ins.pas';
%include 'volx/volx.ins.pas';
%include 'os/os.ins.pas';
%include 'flop/flop.ins.pas';

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  flop_$boot;

{ ---- OS_INIT_PROC ---- }
%include 'flop/boot.pas';                   { FLOP_$BOOT, with
                                              flop_$boot_errchk and
                                              flop_$mount_floppy
                                              nested }
