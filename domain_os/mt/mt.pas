{ mt/mt.pas - the MT module, the magnetic tape driver.

  Image addresses:
    sau3  0x00E2CC7C  MT data (WIRED_DATA, 0x54 bytes)
    sau4  0x0F83124C  MT data (WIRED_DATA, 0x54 bytes)
    sau5  0x00E2F44C  MT data (WIRED_DATA, 0x54 bytes)

  Configured out on the SAU2 (the SAU3..SAU6 have the driver, the part
  `mt_driver', base/config.ins.pas): there one compilation unit, one
  code segment, no data.  The map's MT code segment in .TEXT, 4 bytes,
  holds MT_$RELEASE's empty body and the compiled module-end filler.

  With the driver the module has one code segment and one data segment:
  on the SAU5 the map's MT code segment in .TEXT (0x1448 bytes:
  module-local routines, MT_PURGE_UCB, and the MT_$ globals from
  MT_$ACQUIRE to MT_$WRITE), and its MT data segment in WIRED_DATA (0x54
  bytes, all zero, no map symbol inside).  The SAU3's code is the
  SAU5's but for the I/O map entries: longwords with the long_iomap
  part, the first word of each entry's 4 bytes without it
  (pbu/pbu.ins.pas).

  The heading names no code section and wired_data as the data section,
  PCHIST's form (pchist/pchist.pas, ref 7.1.1).  It is the same on every
  SAU: the configuration is not known before it, and the SAU2's module
  has no variables, so the section it names for them stays empty.

  Not part of the module:

  - the map's MT_$SIO code segment (MT_$SIO and MT_$GET_IOVA): its own
    module, mt/mt_sio.pas;
  - the map's MT_ASM data segment, the MT_PAGE section (0xC00 bytes on
    the SAU3..SAU6, empty on the SAU2): hand assembly, the MT_$
    routines of the MT page and the controller's block MT_$SCB,
    mt/m68k/mt_asm.s;
  - the map's MT_END_ADDR segment (4 bytes), which holds MT_$PROC_END:
    a marker segment, hand assembly, mt/m68k/end_addr.s;
  - MT_$PROC_START, a layout mark (on the SAU2 at MT_$PROC_END, on the
    SAU3 and SAU5 at MT_$SIO);
  - on the SAU2, MT_$DATA_START and MT_$DATA_END, both at the start of
    the map's AUDIT data segment: markers of an empty data area.

  The data block, 0x54 bytes (zero):

    +0x00  mt_wired        the driver's wired pages, 20 (WP_$UNWIRE's
                           arguments)
    +0x50  mt_wired_count  their count

  The routines live in one fragment file each (mt/<name>.pas), in image
  order.

  Check: tools/pascal_check.sh.
}
module mt, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';                     { pbu/pbu.ins.pas's eventcount types }
%if mt_driver %then
%include 'ml/ml.ins.pas';
%include 'wp/wp.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'as/as.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'io/io.ins.pas';
%endif
%include 'pbu/pbu.ins.pas';                   { the PBU routines MT calls }
%include 'mt/mt.ins.pas';

%if mt_driver %then
var
  mt_wired: array[1..mt_max_wired] of integer32;  { +0x00 }
  mt_wired_count: integer;                        { +0x50 }
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if mt_driver %then
  mt_purge_ucb;
  mt_$acquire;
  mt_$chain_read;
  mt_$chain_write;
  mt_$control;
  mt_$erase;
  mt_$present;
  mt_$purge_pb;
  mt_$read;
%endif
  mt_$release;
%if mt_driver %then
  mt_$set_mode;
  mt_$space;
  mt_$unwire;
  mt_$wait;
  mt_$wire;
  mt_$write;
%endif

%if mt_driver %then
{ ---- .TEXT ---- }
%include 'mt/shutdown.pas';                { mt_$shutdown }
%include 'mt/purge_ucb.pas';               { MT_PURGE_UCB }
%include 'mt/queue_request.pas';           { mt_$queue_request }
%include 'mt/release_unit.pas';            { mt_$release_unit }
{ (init_unit and mt_$set_iomap are nested in MT_$ACQUIRE: mt/acquire.pas
  includes mt/set_iomap.pas.) }
%include 'mt/acquire.pas';                 { MT_$ACQUIRE, init_unit }
%include 'mt/chain_read.pas';              { MT_$CHAIN_READ }
%include 'mt/chain_write.pas';             { MT_$CHAIN_WRITE }
%include 'mt/control.pas';                 { MT_$CONTROL }
%include 'mt/erase.pas';                   { MT_$ERASE }
%include 'mt/present.pas';                 { MT_$PRESENT }
%include 'mt/purge_pb.pas';                { MT_$PURGE_PB }
%include 'mt/read.pas';                    { MT_$READ }
%include 'mt/release.pas';                 { MT_$RELEASE }
%include 'mt/set_mode.pas';                { MT_$SET_MODE }
%include 'mt/space.pas';                   { MT_$SPACE }
%include 'mt/unwire.pas';                  { MT_$UNWIRE }
%include 'mt/wait.pas';                    { MT_$WAIT }
%include 'mt/wire.pas';                    { MT_$WIRE }
%include 'mt/write.pas';                   { MT_$WRITE }
%else

{ ---- .TEXT ---- }
%include 'mt/release.pas';                 { MT_$RELEASE }
%endif
