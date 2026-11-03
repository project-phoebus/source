{ pbu/pbu.pas - the PBU module, processor bus unit support.

  Image addresses:
    sau3  0x00E82448  PBU data (.DATA, 0x5C bytes)
    sau5  0x00E88048  PBU data (.DATA, 0x5C bytes)

  Configured out of the SAU2 and SAU9 kernels: there one compilation
  unit, one code segment, no data: the map's PBU code segment in .TEXT
  (0x18 bytes: PBU_$FREE_ASID, PBU_$FAULTED_UNITS, PBU_$INIT), two empty
  procedures and a function that reports "pbu not present".  The map's
  PBU_TABLES is an empty section there.

  With the driver (`pbu_driver', base/config.ins.pas: the SAU3..SAU8)
  the module is the user-device manager: it sets up the PBU units a
  device descriptor file (DDF) describes, wires and maps the units'
  buffers and controller memory, and keeps their eventcounts.

  On the SAU5 one code segment in .TEXT (0x1FC0 bytes: five module-local
  routines, two of them nested, and the 32 globals) and one data segment
  in .DATA (0x5C bytes).  On the SAU3 the same with 0x1ADC bytes of code:
  four module-local routines (PBU2_$ASSOC's nested window_free is the
  VME bus's, `vme_bus'), 8 units (`pbu_8_units'), word I/O map entries
  (no `long_iomap') and PBU_$WIRE_SPECIAL without its body (no
  `pbu_wire_special').

  Not part of the module (pbu_driver):

  - PBU_ASM, the PBU page's hand-written data and routines (SM_$CB,
    PBU_$MCB, PBU_$INT_COM, PBU_$TRAP6, PBU_$DCTES, PBU_$DCTE_TABLE,
    PBU_$ENABLE_DEVICE ...): pbu/sau5/pbu_asm.s;
  - PBU_MAP, the map's module of PBU2_$MAP, PBU2_$UNMAP and the DMA
    entries, in PBU_WIRED_PROC (pbu/pbu_map.pas);
  - EC2_PBU (pbu/ec2_pbu.pas), on every SAU;
  - PBU_TABLES, the map's data segment of PBU_$PPN_OWNERS, a fixed
    address in the low region with no bytes in the image.

  The data block, 0x5C bytes (zero except the value given):

    +0x00  pbu_wired_pages  the PBU page's wired pages, 21
    +0x54  pbu_default_ctl  a new DCTE's transfer control, 16#48000
                            (16#80000000 without `long_iomap')
    +0x58  pbu_wired_count  the count of pbu_wired_pages
    (the block's last two bytes are the compiler's padding)

  The routines live in one fragment file each (pbu/<name>.pas), in image
  order; the nested routines are in their parents' files.

  Check: tools/pascal_check.sh.
}
module pbu;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%if pbu_driver %then
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'as/as.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%endif
%include 'pbu/pbu.ins.pas';
%if pbu_driver %then
%include 'io/io.ins.pas';
%include 'mbus/mbus.ins.pas';
%endif

%if pbu_driver %then
{ TODO(sau) the SAU4 and SAU6..SAU8 PBU code

  The module's code below is the SAU5's and the SAU3's.  27 of the 32
  PBU routines differ between the SAUs with the driver
  (tools/sau_catalog.py), and the code segments differ in size (0x1ADC
  on the SAU3, 0x1938 on the SAU4, 0x1FC0 on the SAU5, 0x1F7C on the
  SAU6): the other SAUs need their own forms, with their own parts,
  when they are translated. }

var
  pbu_wired_pages: array[1..pbu_max_wired_pages] of integer32;  { +0x00 }
%if long_iomap %then
  pbu_default_ctl: pbu_$ctl_t := [wide := true, bit_15 := true];
                                                { +0x54: 16#48000 }
%else
  pbu_default_ctl: pbu_$ctl_t := [bit_15 := true];
                                                { +0x54: 16#80000000 }
%endif
  pbu_wired_count: integer;                     { +0x58 }
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if pbu_driver %then
  pbu_$acquire_int;
  pbu_$alloc;
  pbu_$advance_ec;
  pbu_$allocate_ec;
  pbu2_$allocate_map;
  pbu2_$assoc;
  pbu_$control;
  pbu_$dissoc;
  pbu_$free;
  pbu_$free_map;
  pbu_$get_dcte;
  pbu_$get_ec;
  pbu_$get_info;
  pbu_$get_ptr;
  pbu_$release_ec;
  pbu_$release_int;
  pbu_$setdown;
  pbu_$setup;
  pbu_$shutdown;
  pbu2_$unwire;
  pbu_$delete_ppn;
  pbu_$unwire_user_pages;
  pbu_$save_ppn;
  pbu2_$wire;
  pbu2_$wire_map;
  pbu_$wire_special;
  pbu_$wire_pbu;
  pbu_$read_csr;
  pbu_$write_csr;
  pbu_$init;
  pbu_$free_asid;
  pbu_$faulted_units;
%else
  pbu_$free_asid;
  pbu_$faulted_units;
  pbu_$init;
%endif

{ ---- .TEXT ---- }
%if pbu_driver %then
%include 'pbu/check_unit.pas';              { pbu_check_unit }
%include 'pbu/acquire_int.pas';             { PBU_$ACQUIRE_INT }
%include 'pbu/alloc.pas';                   { PBU_$ALLOC }
%include 'pbu/advance_ec.pas';              { PBU_$ADVANCE_EC }
%include 'pbu/allocate_ec.pas';             { PBU_$ALLOCATE_EC }
%include 'pbu/pbu2_allocate_map.pas';       { PBU2_$ALLOCATE_MAP }
%include 'pbu/pbu2_assoc.pas';              { PBU2_$ASSOC }
%include 'pbu/control.pas';                 { PBU_$CONTROL }
%include 'pbu/dissoc.pas';                  { PBU_$DISSOC }
%include 'pbu/clear_iomap.pas';             { pbu_clear_iomap }
%include 'pbu/free.pas';                    { PBU_$FREE }
%include 'pbu/free_map.pas';                { PBU_$FREE_MAP }
%include 'pbu/get_dcte.pas';                { PBU_$GET_DCTE }
%include 'pbu/get_ec.pas';                  { PBU_$GET_EC }
%include 'pbu/get_info.pas';                { PBU_$GET_INFO }
%include 'pbu/get_ptr.pas';                 { PBU_$GET_PTR }
%include 'pbu/release_ec.pas';              { PBU_$RELEASE_EC }
%include 'pbu/release_int.pas';             { PBU_$RELEASE_INT }
%include 'pbu/setdown.pas';                 { PBU_$SETDOWN }
%include 'pbu/setup.pas';                   { PBU_$SETUP }
%include 'pbu/shutdown.pas';                { PBU_$SHUTDOWN }
%include 'pbu/pbu2_unwire.pas';             { PBU2_$UNWIRE }
%include 'pbu/delete_ppn.pas';              { PBU_$DELETE_PPN }
%include 'pbu/unwire_user_pages.pas';       { PBU_$UNWIRE_USER_PAGES }
%include 'pbu/save_ppn.pas';                { PBU_$SAVE_PPN }
%include 'pbu/pbu2_wire.pas';               { PBU2_$WIRE }
%include 'pbu/pbu2_wire_map.pas';           { PBU2_$WIRE_MAP }
%include 'pbu/wire_special.pas';            { PBU_$WIRE_SPECIAL }
%include 'pbu/wire_pbu.pas';                { PBU_$WIRE_PBU }
%include 'pbu/access_csr.pas';              { pbu_access_csr }
%include 'pbu/read_csr.pas';                { PBU_$READ_CSR }
%include 'pbu/write_csr.pas';               { PBU_$WRITE_CSR }
%include 'pbu/init.pas';                    { PBU_$INIT }
%include 'pbu/free_asid.pas';               { PBU_$FREE_ASID }
%include 'pbu/faulted_units.pas';           { PBU_$FAULTED_UNITS }
%else
%include 'pbu/free_asid.pas';               { PBU_$FREE_ASID }
%include 'pbu/faulted_units.pas';           { PBU_$FAULTED_UNITS }
%include 'pbu/init.pas';                    { PBU_$INIT }
%endif
