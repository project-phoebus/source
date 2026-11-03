{ lpr/lpr.pas - the LPR_ module, the line printer driver.

  Image addresses:
    sau3  0x00E8417C  LPR_ data (.DATA, 0x64 bytes)
    sau4  0x0F893808  LPR_ data (.DATA, 0x50 bytes)

  Where the driver is configured out (the SR10.2 SAU2, SAU5..SAU9) the
  module is empty: what is left of the driver is hand assembly
  (lpr/m68k/release.s, end_addr.s).

  With the driver (`lpr_driver', base/config.ins.pas), on the SAU3: one
  compilation unit in two code sections and one data section: the map's
  LPR_ code segments in OS_INIT_PROC (0x5C bytes: LPR_$INIT) and .TEXT
  (0x3C0 bytes: lpr_set_mode at LPR_$PROC_START, LPR_$STATE,
  LPR_$WRITE, LPR_$ACQUIRE, LPR_$RELEASE), and its data segment in .DATA
  (0x64 bytes, below).  LPR_ASM, the port's interrupt routine, its data
  and the buffer (0x2F4 bytes in .DATA), is hand assembly
  (lpr/sau3/lpr_asm.s); CBUF (cbuf/) and LPR_END_ADDR follow LPR_'s
  .TEXT code, inside its wired range.

  On the SAU4 (`lpr_pbu_unit') the port is the PNA's, the PBU's unit 6:
  LPR_ in OS_INIT_PROC (0x50 bytes: LPR_$INIT) and .TEXT (0x358 bytes:
  LPR_$STATE, which is LPR_$PROC_START, LPR_$WRITE, LPR_$ACQUIRE,
  LPR_$RELEASE), a block of 0x50 bytes (the SAU3's without the stand-in
  and the mode table), and LPR_ASM's 0x2C4 bytes (lpr/sau4/lpr_asm.s):
  LPR_$INT is the unit's device routine, with no enable routines.

  The heading names no section: the block's objects are module
  variables, reached through A5 in .TEXT and by their address from
  LPR_$INIT (`[section(os_init_proc, os_init_data)]').

  The data block (zero except the mode table):

    +0x00  lpr_wire_list   the driver's wired pages, 10
    +0x28  lpr_$bcb        the circular buffer's control block
    +0x44  unused_44       4 bytes nothing addresses (a stand-in)
    +0x48  lpr_modes       the three modes' register values:
                           00 00 00 10 00, 03 00 00 13 FF, 00 04 04 10 FF
    +0x5A  lpr_state       the port's flags and the mode
    +0x5C  lpr_wire_count  the count of lpr_wire_list
    +0x5E  lpr_owner       the acquiring process, 0 for none
    +0x60  lpr_acquired    the printer is acquired
    +0x62  lpr_$present    the port answered LPR_$INIT's probe

  The routines live in one fragment file each (lpr/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module lpr_;

%include 'base/base.ins.pas';
%if lpr_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'io/io.ins.pas';
%include 'uid/uid.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'cbuf/cbuf.ins.pas';
%if lpr_pbu_unit %then
%include 'pbu/pbu.ins.pas';
%include 'mbus/mbus.ins.pas';
%endif
%include 'lpr/lpr.ins.pas';

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above). }
define
  lpr_$init;
  lpr_$state;
  lpr_$write;
  lpr_$acquire;
  lpr_$release;

var
  lpr_wire_list: array[1..10] of integer32;     { +0x00 }

define
  lpr_$bcb;                                     { +0x28 }

%if lpr_pbu_unit %then
var
  lpr_state: lpr_$state_t;                      { +0x44 }
  lpr_wire_count: integer;                      { +0x46 }
  lpr_owner: pinteger;                          { +0x48 }
  lpr_acquired: boolean;                        { +0x4A }

define
  lpr_$present;                                 { +0x4C }

{ ---- OS_INIT_PROC ---- }
%include 'lpr/init.pas';                    { LPR_$INIT }

{ ---- .TEXT ---- }
%include 'lpr/state.pas';                   { LPR_$STATE }
%include 'lpr/write.pas';                   { LPR_$WRITE }
%include 'lpr/acquire.pas';                 { LPR_$ACQUIRE }
%include 'lpr/release.pas';                 { LPR_$RELEASE }
%else
var
  unused_44: integer32;                         { +0x44: stand-in }
  lpr_modes: array[0..2] of lpr_$mode_t := [
    [0, 0, 0, 16#10, 0],
    [3, 0, 0, 16#13, 16#FF],
    [0, 4, 4, 16#10, 16#FF]];                   { +0x48 }
  lpr_state: lpr_$state_t;                      { +0x5A }
  lpr_wire_count: integer;                      { +0x5C }
  lpr_owner: pinteger;                          { +0x5E }
  lpr_acquired: boolean;                        { +0x60 }

define
  lpr_$present;                                 { +0x62 }

{ The module-local routine LPR_$INIT calls before its body. }
{ body: lpr/set_mode.pas }
procedure lpr_set_mode; forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'lpr/init.pas';                    { LPR_$INIT }

{ ---- .TEXT ---- }
%include 'lpr/set_mode.pas';                { lpr_set_mode }
%include 'lpr/state.pas';                   { LPR_$STATE }
%include 'lpr/write.pas';                   { LPR_$WRITE }
%include 'lpr/acquire.pas';                 { LPR_$ACQUIRE }
%include 'lpr/release.pas';                 { LPR_$RELEASE }
%endif
%endif
