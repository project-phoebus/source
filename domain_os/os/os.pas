{ os/os.pas - the OS module, the kernel's start-up and shutdown.

  Image addresses:
    sau2  0x00E351F4  OS data (OS_INIT_DATA, 0x188 bytes)
    sau2  0x00E82728  OS data (.DATA, 0x18 bytes)
    sau3  0x00E335F4  OS data (OS_INIT_DATA, 0x188 bytes)
    sau3  0x00E83CBC  OS data (.DATA, 0x18 bytes)
    sau3  0x00E2CB78  OS data (WIRED_DATA, 0x20 bytes)
    sau5  0x00E379F4  OS data (OS_INIT_DATA, 0x194 bytes)
    sau5  0x00E89A44  OS data (.DATA, 0x18 bytes)
    sau5  0x00E2F300  OS data (WIRED_DATA, 0x20 bytes)
    sau8  0x03C39678  OS data (OS_INIT_DATA, 0x2A8 bytes)
    sau8  0x03C9B218  OS data (.DATA, 0x18 bytes)
    sau9  0x3C43BE64  OS data (OS_INIT_DATA, 0x10B0 bytes)
    sau9  0x3C49AEAC  OS data (.DATA, 0x18 bytes)

  One compilation unit, in two code sections and two data sections: the
  map's OS code segments in OS_INIT_PROC (0x1564 bytes, OS_$INIT and
  OS_$BOOT_ERRCHK with two module-local routines) and in .TEXT (0x52C
  bytes, VTOP_OR_CRASH .. OS_$GET_EC with four module-local routines),
  and its OS data segments in OS_INIT_DATA (0x188 bytes) and .DATA (0x18
  bytes, with the map symbols OS_$BOOT_DEVICE, OS_$SHUTTING_DOWN_FLAG).

  Each data block is its code section's partner (A5 in the routines
  that use it) and holds, but for the two map symbols, routines' statics:

    OS_INIT_DATA, 0x188 bytes:
      +0x000  OS_$INIT's statics (os/init.pas): zero to +0xDF, then the
              table from +0xE0
      +0x180  OS_$BOOT_ERRCHK's wait_delay
      +0x186  2 bytes: the block's rounding to 4

    .DATA, 0x18 bytes (the last 2 the block's rounding):
      +0x00   OS_$BOOT_DEVICE (`define'd), 8 bytes, zero
      +0x08   unused_08, a stand-in (see the TODO below), zero
      +0x0C   OS_$SHUTTING_DOWN_FLAG (`define'd), a boolean, zero
      +0x0E   2 bytes: the next object's alignment
      +0x10   OS_$SHUTDOWN's wait_delay

  With `vme_bus' the OS_INIT_DATA block is 0x194 bytes (OS_$INIT's
  vector table 43 cells); with `power_off_check' the unit has a third
  code section and data block (os/init_power_off_check.pas and
  os/check_power_off.pas).

  Without `display_driver' (the SAU3) .TEXT has no
  OS_$INSTALL_DISPLAY_ASTE.

  On the SAU9 OS_INIT_DATA is 0x10B0 bytes (MMAP_$INIT's table of 1024
  longwords, the vector table's 42 cells from +0x1000).  With
  `crash_reboot' the .DATA block has restart_code at +0x0C and
  OS_$SHUTTING_DOWN_FLAG at +0x0E.  With `large_address_space'
  OS_INIT_PROC has os_$free_gap_pmaps before OS_$INIT.

  On the SAU8 OS_INIT_DATA is 0x2A8 bytes (MMAP_$INIT's table of 128
  longwords, the vector table's 40 cells from +0x200), and OS_$INIT
  calls MMU_$SET_SEG_PROT (declared here with the other MMU headings).

  The heading: the define'd variables lie in the default .DATA section
  with the .TEXT routines' statics, so the unit names no sections, `module
  os;' (TTY's shape); the OS_INIT_PROC routines are headed
  `[section(os_init_proc, os_init_data)]', their statics going to
  OS_INIT_DATA (ref 5.7.1, "Section").

  Other units' objects with OS_ names (their fragments, where they have
  one, are in this directory):

  - OS_$SHUTDOWN_EC: OS_WIRED_START's (os/os_wired_start.pas).
  - OS_$REV, BUILD_$TIME, OS_$GET_REV_INFO: PRINT_BUILD_TIME's (misc/).
  - OS_$DATA_COPY, OS_$DATA_ZERO: hand assembly in NETWORK_ASM.
  - OS_DISK_PROC: VTOC_'s; os_term_init: OS_TERM_INIT's;
    OS_PROC_SHUTWIRED: FILE_'s.

  The routines live in one fragment file each, included below in image
  order: os/*.pas, and two fragments of other subsystems,
  network/fetch_diskless_info.pas and misc/prompt_for_yes_or_no.pas.
  The OS_INIT_PROC routines call the .TEXT ones by absolute address, so
  the module-local ones among those have forward headings below.

  Build: dpc -I domain_os domain_os/os/os.pas.  Check:
  tools/pascal_check.sh.
}
module os;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'as/as.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%if pft_mmu %then
%include 'mmu/mmu.ins.pas';
%else

{ TODO(pascal) MMU's headings for the other MMU belong in mmu/mmu.ins.pas

  Without the page frame table MMU (`pft_mmu') MMU_$REMOVE takes a
  virtual address and a word (os_$free_va_page passes 0), where
  mmu/mmu.ins.pas declares the one-argument form its other callers use
  under every configuration; and OS_$INIT passes MMU_$REMOVE_SPECIAL_SEG
  a boolean third argument, where MONO9 passes a word 0 (mmu/mmu.ins.pas
  declares the word).  As win_scsi/win_scsi.ins.pas and
  mst/mst_unwired.pas do, this module declares the MMU headings it uses
  here and does not include mmu/mmu.ins.pas, until that file carries
  these forms under a part of their own, once every caller has its
  form. }

{ MMU_$NORMAL_MODE, MMU_$SET_SYSREV, MMU_$POWER_OFF (hand assembly): no
  arguments; the two functions' booleans in D0. }
function mmu_$normal_mode: boolean; extern;
procedure mmu_$set_sysrev; extern;
function mmu_$power_off: boolean; extern;

{ MMU_$VTOP (hand assembly): the virtual address by value; the page
  number in D0. }
function mmu_$vtop(va: integer32; out status: status_$t): integer32;
  options(extern, val_param);

{ MMU_$REMOVE (hand assembly): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);

{ MMU_$PURGE (hand assembly): flush the address translation cache and
  the virtual cache. }
procedure mmu_$purge; extern;

{ MMU_$MCR_CHANGE (hand assembly): the bit number of the memory control
  register to change, a word by value. }
procedure mmu_$mcr_change(bit: integer); options(extern, val_param);

{ MMU_$REMOVE_SPECIAL_SEG (hand assembly): remove a special segment's
  pages from an address space; the segment's address, the ASID, and
  whether to clear its page descriptors' resident bits too (the routine
  tests the word), by value. }
procedure mmu_$remove_special_seg(va: univ_ptr; asid: integer;
                                  clear_pages: boolean);
  options(extern, val_param);

{ MMU_$PAGE_WRITE_BIT (map symbol; hand assembly): write-protect the
  page at an address unless bit 2 of the protection (the write
  permission) is set, then MMU_$PURGE; the address and the protection
  word, by value. }
procedure mmu_$page_write_bit(va: univ_ptr; prot: integer);
  options(extern, val_param);

%if vector_seg_prot %then
{ MMU_$SET_SEG_PROT (map symbol; hand assembly): set the protection of
  the segment at an address; the address and the protection word, by
  value (OS_$INIT's pushes). }
procedure mmu_$set_seg_prot(va: univ_ptr; prot: integer);
  options(extern, val_param);
%endif
%endif
%include 'mmap/mmap.ins.pas';
%include 'mst/mst.ins.pas';
%include 'fim/fim.ins.pas';
%include 'svc/svc.ins.pas';
%include 'peb/peb.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'acl/acl.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'rip/rip.ins.pas';
%include 'sock/sock.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'ring/ring.ins.pas';
%include 'ring/ring_driver.ins.pas';
%include 'asknode/asknode.ins.pas';
%include 'pacct/pacct.ins.pas';
%include 'log/log.ins.pas';
%include 'audit/audit.ins.pas';
%include 'hint/hint.ins.pas';
%include 'cal/cal.ins.pas';
%include 'fp/fp.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'area/area.ins.pas';
%include 'mst/mst_internal.ins.pas';        { SMAPS, RARS and their bases,
                                              the segment constants }
%include 'volx/volx.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'bat/bat.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'smd/smd.ins.pas';
%include 'gpu/gpu.ins.pas';
%include 'tpad/tpad.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'misc/misc.ins.pas';
%include 'os/os.ins.pas';
%include 'color/color.ins.pas';
%include 'color2/color2.ins.pas';
%include 'pbu/pbu.ins.pas';
%include 'proc2/proc2_data.ins.pas';
%include 'xpd/xpd.ins.pas';
%include 'name/name.ins.pas';
%include 'pchist/pchist.ins.pas';
%include 'mem/mem.ins.pas';
%include 'netlog/netlog.ins.pas';             { netlog_$kinds_t, for asknode_info's
                                               records }
%include 'asknode/asknode_info.ins.pas';  { ASKNODE_$INTERNET_INFO }
%if iic_driver %then
%include 'iic/iic.ins.pas';                 { IIC_$INIT }
%endif
%if lpr_driver %then
%include 'cbuf/cbuf.ins.pas';
%include 'lpr/lpr.ins.pas';                 { LPR_$INIT }
%endif
%if vme_bus %then
%include 'mbus/mbus.ins.pas';
%include 'vme/vme.ins.pas';                 { VME_$INT, VME_$ERR_INT,
                                              VME_CTL }
%endif

{ The module's own variables and the globals it defines (ref 7.2.2,
  7.3.4), in the order of the .DATA block (above). }
define
  os_$boot_device;                                 { +0x00, zero }

var
  unused_08: integer32;                            { +0x08, zero: a
                                                     stand-in }

{ TODO(pascal) The .DATA block's longword at +0x08

  +0x08..+0x0B of the .DATA block lies between OS_$BOOT_DEVICE (8
  bytes) and OS_$SHUTTING_DOWN_FLAG (+0x0C).  No instruction of the OS
  unit addresses it (the .TEXT routines' A5 operands are +0x0C and +0x10
  only), and nothing in the image reaches it by its absolute address.
  An 8-byte alignment does not explain it (the flag is a byte).  The
  stand-in holds the place. }

%if crash_reboot %then
var
  restart_code: integer;                           { +0x0C, zero: the
                                                     PROM's restart code
                                                     for OS_$SHUTDOWN }
%endif

define
  os_$shutting_down_flag;                          { +0x0C, zero; +0x0E
                                                     with `crash_reboot' }

define
  vtop_or_crash;
%if display_driver %then
  os_$install_display_aste;
%endif
  dummy_interrupt_handler;
  os_$shutdown;
  os_$chksum;
  os_$get_ec;
  os_$init;
  os_$boot_errchk;
%if power_off_check %then
  os_$init_power_off_check;
  os_$check_power_off;
%endif

{ DISPLAY1_$UID (map symbol, UID_LIST): smd/smd_internal.ins.pas
  declares it for SMD; declared here too because os.pas does not
  include SMD's internal insert.  OS_$INIT passes its address to
  OS_$INSTALL_DISPLAY_ASTE. }
%if display_driver %then
var
  display1_$uid: extern uid_$t;
%endif

{ DISPLAY2_$UID and DISPLAY3_$UID (map symbols, UID_LIST, after
  DISPLAY1_$UID): OS_$INIT installs the second display's ASTE with the
  first (`disp2_probe') and the DN580's color display's with the second
  (`gpu_driver').  TODO(merge) smd/smd_internal.ins.pas declares
  DISPLAY1_$UID; these belong beside it. }
%if disp2_probe %then
var
  display2_$uid: extern uid_$t;
%endif
%if gpu_driver %then
var
  display3_$uid: extern uid_$t;

{ TODO(merge) gpu/gpu.ins.pas: GPU, the graphics processor's register
  page

  GPU (map symbol, an absolute address of the I/O space, the SAU5's
  IODEFS run): OS_$INIT probes the word at +2 with TESTPAGE, the
  location the field's address (a computed argument, not a constant
  cell).  Only that word is named here. }
type
  os_$gpu_regs_t = [device] record
    unused_00: integer;                   { 0x00 }
    reg_02: integer;                      { 0x02 }
  end;
var
  gpu: extern os_$gpu_regs_t;
%endif

%if pmmu_page_maps %then
{ OS_PMAPS (map symbol without `$', the second object of the OS_PMAPS
  load section, after MMAP): the page maps of global B's 2048 segments,
  0x80 bytes each (ast/ast.ins.pas ast_$pmap_t), element 0 the first
  segment of global B (OS_$INIT, OS_$INSTALL_DISPLAY_ASTE and
  os_$free_gap_pmaps clear their descriptors' resident bits and free
  their pages). }
var
  os_pmaps: extern array[0..2047] of ast_$pmap_t;
%endif

{ Module-local routines of .TEXT called from OS_INIT_PROC, before their
  bodies in source order. }
{ body: os/print_init_error.pas }
procedure os_$print_init_error(in msg: univ vfmt_$string_t);
  forward; internal;
{ body: os/free_va_page.pas }
procedure os_$free_va_page(vaddr: integer32); forward; internal;
{ body: os/start_proc2.pas }
procedure os_$start_proc2(in ctx: fim_$startup_context_t);
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'network/fetch_diskless_info.pas'; { network_$fetch_diskless_info }
%include 'misc/prompt_for_yes_or_no.pas';   { prompt_for_yes_or_no }
%if large_address_space %then
%include 'os/free_gap_pmaps.pas';           { os_$free_gap_pmaps }
%endif
%include 'os/init.pas';                     { OS_$INIT }
%include 'os/init_power_off_check.pas';     { OS_$INIT_POWER_OFF_CHECK }
%include 'os/check_power_off.pas';          { OS_$CHECK_POWER_OFF (in
                                              WIRED_PROC) }
%include 'os/boot_errchk.pas';              { OS_$BOOT_ERRCHK }

{ ---- .TEXT ---- }
%include 'os/print_init_error.pas';         { os_$print_init_error }
%include 'os/vtop_or_crash.pas';            { VTOP_OR_CRASH }
%include 'os/free_ppn.pas';                 { os_$free_ppn }
%include 'os/free_va_page.pas';             { os_$free_va_page }
%include 'os/start_proc2.pas';              { os_$start_proc2 }
%if display_driver %then
%include 'os/install_display_aste.pas';     { OS_$INSTALL_DISPLAY_ASTE }
%endif
%include 'os/dummy_interrupt_handler.pas';  { DUMMY_INTERRUPT_HANDLER }
%include 'os/shutdown.pas';                 { OS_$SHUTDOWN }
%include 'os/chksum.pas';                   { OS_$CHKSUM }
%include 'os/get_ec.pas';                   { OS_$GET_EC }
