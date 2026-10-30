{ io/io.pas - the IO_ module, the I/O manager.

  Image addresses:
    sau2  0x00E2C368  IO_ data (WIRED_DATA, 0x554 bytes)
    sau5  0x00E2D4A4  IO_ data (WIRED_DATA, 0x684 bytes)
    sau9  0x3C430840  IO_ data (WIRED_DATA, 0x5B4 bytes)

  One compilation unit, `module io_, wired_proc, wired_data;': the map's
  IO_ code segments in WIRED_PROC (CHK, IO_$GET_DCTE .. IO_$ALLOC, and
  with the PBU the I/O map routines), OS_INIT_PROC
  (io_$build_dcte_list, IO_$INIT) and PROCEDURE$ (IO_$GET_CONFIG), each
  headed with its sections, and its data segment in WIRED_DATA (1364
  bytes on the SAU2, 1668 on the SAU5).

  The data, declared below with each object's offset on both SAUs: the
  I/O maps (io_$iomap_area, bus 4's empty on the SAU2; VME's and MBUS's
  too on the SAU5), IO_$BUS_EPV, the unit table IO_$DCTES, the two
  exclusion locks (PBU_$EXCLUSION_LOCK too with the PBU), the region
  nodes (`io_regions'), the DCTE area's bounds and IO_$DCTE_LIST.

  The gaps are declared as fillers so dpc gives the image's offsets;
  most put an object of 8 bytes or more at a multiple of 8.  No SAU2
  routine reads the first 96 bytes, the I/O maps.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/io/io.pas.  Check: tools/pascal_check.sh.
}

module io_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';                { proc1_$current: IO_$ACQUIRE }
%include 'ml/ml.ins.pas';
%if large_vm %then

{ TODO(pascal) MMU's large-VM headings belong in mmu/mmu.ins.pas

  With the large VM layout MMU_$REMOVE takes a virtual address and a
  word (IO_$UNMAP_CSR passes 0), where mmu/mmu.ins.pas declares the
  one-argument form its other callers use under every configuration.
  As mst/mst_unwired.pas does, this module declares the MMU headings it
  uses here and does not include that file, until it carries the other
  form under a part of its own. }

{ MMU_$REMOVE (hand assembly): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);

{ MMU_$INSTALL (hand assembly): the page number and the virtual address,
  longwords, then the ASID and the protection, all by value. }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

{ MMU_$CACHE_INHIBIT_VA (hand assembly): the address by value. }
procedure mmu_$cache_inhibit_va(va: univ_ptr); options(extern, val_param);

{ MMU_$VTOP (hand assembly): the virtual address by value; the page
  number in D0. }
function mmu_$vtop(va: integer32; out status: status_$t): integer32;
  options(extern, val_param);
%else
%include 'mmu/mmu.ins.pas';
%endif
%include 'vfmt/vfmt.ins.pas';
%include 'dma/dma.ins.pas';
%include 'io/io.ins.pas';
%include 'ec/ec.ins.pas';                     { for pbu/pbu.ins.pas }
%include 'pbu/pbu.ins.pas';                   { PBU_$INIT, PBU_$MCB }
%include 'mt/mt.ins.pas';                     { MT_$PRESENT }
%include 'mbus/mbus.ins.pas';                 { IO_$BUS_EPV's Multibus entry }
%include 'vme/vme.ins.pas';                   { IO_$BUS_EPV's VME entry }
%include 'sysbus/sysbus.ins.pas';
%include 'atbus/atbus.ins.pas';               { IO_$BUS_EPV's AT bus entry }
%if prom_config_record %then
%include 'os/os.ins.pas';                     { the PROM's configuration
                                                record, OS_$BOOT_DEVICE }
%include 'time/time.ins.pas';                 { for log/log.ins.pas }
%include 'log/log.ins.pas';                   { LOG_$ADD }
%include 'pkt/pkt.ins.pas';                   { for net_io/net_io.ins.pas }
%include 'net_io/net_io.ins.pas';             { NET_IO_$BOOT_DEVICE }
%endif

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above).  Where the defined variables go among
  the module's own: see the TODO(pascal) in log/log.pas.  The routines'
  map order: CHK (misc/chk.pas), IO_$GET_DCTE, IO_$ACQUIRE ..
  IO_$XLATE_IOVA, IO_$ATTR_CNTL (with the PBU), IO_$ALLOC, IO_$FREE ..
  IO_$FREE_MAP_REGION (with the PBU), IO_$INIT, IO_$LOG_SELF_TESTS (with
  the PROM's configuration record), IO_$GET_CONFIG. }
define
  chk;
  io_$get_dcte;
  io_$acquire;
  io_$release;
  io_$device_interrupting;
  io_$clear_pending;
  io_$disable_device;
  io_$enable_device;
  io_$map_csr;
  io_$unmap_csr;
  io_$xlate_iova;
%if pbu_driver %then
  io_$attr_cntl;
%endif
  io_$alloc;
%if pbu_driver %then
  io_$free;
  io_$alloc_map;
  io_$free_map;
  io_$free_map_region;
%endif
  io_$init;
%if prom_config_record %then
  io_$log_self_tests;
%endif
  io_$get_config;

const
  { The number of region nodes in the block (`io_regions'): IO_$INIT's
    loop count and the 0x10-byte nodes' share of the block: 64 on the
    SAU3, SAU4 and SAU7 (0x400 bytes), 8 on the SAU5 and SAU6 (0x80
    bytes, `few_io_regions'). }
%if few_io_regions %then
  io_$region_count = 8;
%else
  io_$region_count = 64;
%endif

type
  { An I/O map (the header above): a range of indices, first and last
    (first > last: empty), and up to eight ranges of bus addresses, each
    a start and an end.  io_$alloc_region adds a range after the last
    (none past index 7: "(1e0011) no room in iomap") and io_$free_region
    removes one, moving the later ones down; both compare the addresses
    unsigned (linteger). }
  io_$iomap_range_t = record
    start: linteger;                      { 0x00 }
    stop: linteger;                       { 0x04 }
  end;

  io_$iomap_t = record
    first: integer;                       { 0x00: 0001 in the image }
    last: integer;                        { 0x02 }
    ranges: array[0..7] of io_$iomap_range_t;
                                          { 0x04 }
  end;                                    { 0x44 }

  io_$iomap_ptr_t = ^io_$iomap_t;

  { The block's first bytes: the maps' pointers, one per bus number
    (each bus with a map points at it), and the maps, empty: on the SAU2
    one, bus 4's (0x60 bytes in all); on the SAU5 three, bus 1's, bus
    2's and bus 4's (0xF0 bytes).  One record, so that its initializer
    can take the maps' addresses: the pointers come first, and a
    variable can name only itself or an earlier one (the variable in
    scope in its own initializer).  The fillers give the image's offsets
    (each map at a multiple of 8, as the SAU3's and SAU9's maps at +0x18
    and +0x60). }
  io_$iomap_area_t = record
    maps: array[0..4] of io_$iomap_ptr_t; { 0x00 }
    unused_14: integer32;                 { 0x14 }
%if vme_bus %then
    vme_map: io_$iomap_t;                 { 0x18 on the SAU5 }
    unused_vme: integer32;                { 0x5C on the SAU5 }
%endif
%if mbus_bus %then
    mbus_map: io_$iomap_t;                { 0x60 on the SAU5 }
    unused_mbus: integer32;               { 0xA4 on the SAU5 }
%endif
%if atbus_routines %then
    atbus_map: io_$iomap_t;               { 0x18 on the SAU9 }
    unused_atbus: integer32;              { 0x5C on the SAU9 }
%endif
    sysbus_map: io_$iomap_t;              { 0x18; 0xA8 on the SAU5 }
    unused_5c: integer32;                 { 0x5C; 0xEC on the SAU5 }
  end;                                    { 0x60; 0xF0 on the SAU5;
                                            0xA8 on the SAU9 }

var
  io_$iomap_area: io_$iomap_area_t :=
    [maps := [
%if vme_bus %then
              io_$bus_vme := addr(io_$iomap_area.vme_map),
%endif
%if mbus_bus %then
              io_$bus_mbus := addr(io_$iomap_area.mbus_map),
%endif
%if atbus_routines %then
              io_$bus_atbus := addr(io_$iomap_area.atbus_map),
%endif
              io_$bus_sysbus := addr(io_$iomap_area.sysbus_map)],
%if vme_bus %then
     vme_map := [first := 1],
%endif
%if mbus_bus %then
     mbus_map := [first := 1],
%endif
%if atbus_routines %then
     atbus_map := [first := 1],
%endif
     sysbus_map := [first := 1]];
                                          { +0x000 }

{ The bus vectors: each bus's routines where the SAU has the bus's
  module (the parts' evidence is in base/config.ins.pas). }
define
  io_$bus_epv := [io_$bus_vme := [
%if vme_bus %then
                                  init := addr(vme_$init),
                                  define_int := addr(vme_$define_userint),
%endif
                                  csr_align := 16#400],
                  io_$bus_mbus := [
%if mbus_bus %then
                                   init := addr(mbus_$init),
                                   define_int := addr(mbus_$define_int),
                                   enable_device := addr(mbus_$enable_dev),
                                   disable_device := addr(mbus_$disable_dev),
%endif
                                   csr_align := 8],
                  io_$bus_atbus := [
%if atbus_routines %then
                                    init := addr(atbus_$init),
                                    xlate_iova := addr(atbus_$xlate_iova),
                                    define_int := addr(atbus_$define_int),
                                    enable_device :=
                                      addr(atbus_$enable_device),
                                    disable_device :=
                                      addr(atbus_$disable_device),
                                    device_interrupting :=
                                      addr(atbus_$device_interrupting),
                                    clear_pending :=
                                      addr(atbus_$clear_pending),
%endif
                                    csr_align := 8],
                  io_$bus_sysbus := [
%if sysbus_routines %then
                                     init := addr(sysbus_$init),
                                     define_int := addr(sysbus_$define_int),
%endif
%if util_pic %then
                                     enable_device :=
                                       addr(sysbus_$enable_device),
                                     disable_device :=
                                       addr(sysbus_$disable_device),
                                     device_interrupting :=
                                       addr(sysbus_$device_interrupting),
                                     clear_pending :=
                                       addr(sysbus_$clear_pending),
%endif
                                     csr_align := 8]];
                                          { +0x060; +0x0F0 on the SAU5;
                                            +0x0A8 on the SAU9 }

var
  pad_114: integer32;                     { +0x114; +0x1A4 on the SAU5;
                                            +0x15C on the SAU9 }

define
  io_$dctes;                              { +0x118; +0x1A8 on the SAU5;
                                            +0x160 on the SAU9 }

var
  io_$exclusion: ml_$exclusion_t;         { +0x518; +0x5A8 on the SAU5;
                                            +0x560 on the SAU9 }
  pad_52a: array[1..3] of integer;        { +0x52A; +0x5BA on the SAU5;
                                            +0x572 on the SAU9 }

%if scsi_driver %then
define
  scsi_$exclusion_lock;                   { +0x578 on the SAU9 }

var
  pad_scsi_lock: array[1..3] of integer;  { +0x58A on the SAU9 }
%endif

%if pbu_driver %then
define
  pbu_$exclusion_lock;                    { +0x5C0 on the SAU5 }

var
  pad_pbu_lock: array[1..3] of integer;   { +0x5D2 on the SAU5 }
%endif

define
  io_$wiring_exclusion;                   { +0x530; +0x5D8 on the SAU5;
                                            +0x590 on the SAU9 }

%if io_regions %then
var
  pad_wiring: array[1..3] of integer;     { +0x5EA on the SAU5 }

  { The region nodes, a free list built by IO_$INIT (io_$region_free
    below its head), io_$region_count of them (io/io.ins.pas's
    io_$region_t). }
  io_$region_nodes: array[1..io_$region_count] of io_$region_t;
                                          { +0x5F0 on the SAU5 }
%else
var
  pad_542: integer;                       { +0x542; +0x5A2 on the SAU9 }
%endif

var
  io_$dcte_area_end: univ_ptr := addr(dcte_end);
                                          { +0x544; +0x670 on the SAU5 }
  io_$dcte_area_start: univ_ptr := addr(dcte_start);
                                          { +0x548; +0x674 on the SAU5 }

define
  io_$dcte_list;                          { +0x54C; +0x678 on the SAU5 }

%if io_regions %then
var
  io_$region_free: io_$region_ptr_t;      { +0x67C on the SAU5 }
%endif

var
  io_$config_flag: boolean;               { +0x550; +0x680 on the SAU5 }

define
  io_$in_init;                            { +0x552; +0x682 on the SAU5 }

{ ---- WIRED_PROC ---- }
%include 'misc/chk.pas';                    { CHK }
%include 'io/get_dcte.pas';                 { IO_$GET_DCTE }
%include 'io/check_unit.pas';               { io_$check_unit }
%include 'io/acquire.pas';                  { IO_$ACQUIRE, int_ids_match }
%include 'io/release.pas';                  { IO_$RELEASE }
%include 'io/device_interrupting.pas';      { IO_$DEVICE_INTERRUPTING }
%include 'io/clear_pending.pas';            { IO_$CLEAR_PENDING }
%include 'io/disable_device.pas';           { IO_$DISABLE_DEVICE }
%include 'io/enable_device.pas';            { IO_$ENABLE_DEVICE }
%include 'io/map_csr.pas';                  { IO_$MAP_CSR }
%include 'io/unmap_csr.pas';                { IO_$UNMAP_CSR }
%include 'io/xlate_iova.pas';               { IO_$XLATE_IOVA }
%if pbu_driver %then
%include 'io/attr_cntl.pas';                { IO_$ATTR_CNTL }
%include 'io/alloc_region.pas';             { io_$alloc_region, fits }
%include 'io/free_region.pas';              { io_$free_region }
%endif
%include 'io/alloc.pas';                    { IO_$ALLOC }
%if pbu_driver %then
%include 'io/free.pas';                     { IO_$FREE }
%if io_regions %then
%include 'io/add_region.pas';               { io_$add_region }
%include 'io/remove_region.pas';            { io_$remove_region }
%endif
%include 'io/alloc_map.pas';                { IO_$ALLOC_MAP }
%include 'io/free_map.pas';                 { IO_$FREE_MAP }
%include 'io/free_map_region.pas';          { IO_$FREE_MAP_REGION }
%endif

{ ---- OS_INIT_PROC ---- }
%include 'io/build_dcte_list.pas';          { io_$build_dcte_list }
%if prom_config_record %then
%include 'io/match_device.pas';             { io_$match_device }
%endif
%include 'io/init.pas';                     { IO_$INIT }
%if prom_config_record %then
%include 'io/log_self_tests.pas';           { IO_$LOG_SELF_TESTS }
%endif

{ ---- PROCEDURE$ ---- }
%include 'io/get_config.pas';               { IO_$GET_CONFIG }
