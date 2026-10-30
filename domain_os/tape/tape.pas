{ tape/tape.pas - the TAPE_BOOT module: booting from tape.

  Image addresses:
    sau2  0x00E3514C  TAPE_BOOT data (OS_INIT_DATA, 4 bytes)
    sau5  0x00E3794C  TAPE_BOOT data (OS_INIT_DATA, 4 bytes)
    sau9  0x3C43BDF8  TAPE_BOOT data (OS_INIT_DATA, 4 bytes)

  One compilation unit: the map's TAPE_BOOT code segment in OS_INIT_PROC
  (0x10 bytes on the SAU2, TAPE_$BOOT; 0xA68 bytes on the SAU5,
  0xA60 on the SAU9, TAPE_$BOOT and its ten nested routines) and its
  data segment in OS_INIT_DATA (4 bytes, zero, never addressed).
  Configured out on the SAU2..SAU4; the SAU5..SAU9 have it
  (`tape_boot', base/config.ins.pas).

  The heading names no section; TAPE_$BOOT carries
  `[section(os_init_proc, os_init_data)]'.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/tape/tape.pas.  Check: tools/pascal_check.sh.
}
module tape_boot;

{ TODO(pascal) the 4-byte OS_INIT_DATA block that nothing addresses

  The map's 4-byte TAPE_BOOT data segment (zero) has no object of the
  source that this module can name: TAPE_$BOOT has no statics and never
  loads A5.  Eleven modules with OS_INIT_PROC code have such a 4-byte
  OS_INIT_DATA block.
  Until the cause is known, dpc emits no block for this module, and the
  image has 4 bytes. }

%include 'base/base.ins.pas';
%if tape_boot %then
%include 'misc/crash_system.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'mst/mst.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'os/os.ins.pas';
%include 'ct/ct.ins.pas';
%endif
%include 'tape/tape.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  tape_$boot;

{ ---- OS_INIT_PROC ---- }
%include 'tape/boot.pas';                   { TAPE_$BOOT }
