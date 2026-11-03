{ pbu/pbu_map.pas - the PBU_MAP module, the PBU's interrupt-level I/O
  map and DMA entries and its wait.

  Image addresses:
    sau3  0x00E8A054  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau5  0x00E9241C  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau8  0x03CA5CB8  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)

  On the SAUs with the PBU driver (`pbu_driver', base/config.ins.pas):
  one compilation unit, one code segment and one data segment, each in
  a section of its own: the map's PBU_MAP code segment in PBU_WIRED_PROC
  (0x44C bytes on the SAU5: two module-local routines, the DMA entries,
  PBU2_$MAP, PBU2_$UNMAP, PBU_$WAIT) and its data segment in
  PBU_WIRED_DATA (0xC bytes).

  On the SAU3 the same routines in 0x450 bytes: PBU2_$MAP and
  PBU2_$UNMAP write word I/O map entries (no `long_iomap'), the
  module-local routines take `pbu_8_units' (pbu/pbu.ins.pas).

  On the SAU8 0x5F4 bytes: three module-local routines (the third,
  pbu_map_dma_error, the AT bus's), the DMA entries driving the AT
  bus's DMA channels (`pbu_atbus_units', `atbus_dma'), PBU2_$MAP and
  PBU2_$UNMAP as stubs (no I/O map space, `io_regions'), PBU_$WAIT.

  Without the driver the module compiles to nothing.

  Its code is wired with the PBU page (PBU_$WIRE_PBU): user handlers
  call PBU2_$MAP, PBU2_$UNMAP and the DMA entries through PBU_$TRAP6 at
  interrupt level.  EC2_PBU (pbu/ec2_pbu.pas) follows it in both
  sections.

  Not part of the module: PBU_$PAGE_END, the map's symbol at the
  module's first byte, a marker: the end of the PBU page's hand-written
  part (pbu/sau5/pbu_asm.s, pbu/sau3/pbu_asm.s).

  The data block, 0xC bytes, zero: a longword nothing names, then the
  map's PBU_$DCTE_INT_PTR and PBU_$VME_DISABLE_COUNT, defined variables
  (pbu/pbu.ins.pas).  Nothing in the SAU5 image refers to any of it.

  The routines live in one fragment file each (pbu/<name>.pas), in image
  order.

  Check: tools/pascal_check.sh.
}
module pbu_map, pbu_wired_proc, pbu_wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%if pbu_driver %then
%include 'ml/ml.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'io/io.ins.pas';
%if atbus_dma %then
%include 'dma/dma.ins.pas';
%endif
%endif
%include 'pbu/pbu.ins.pas';

%if pbu_driver %then
{ TODO(sau) the SAU4, SAU6 and SAU7 PBU_MAP code

  The module's code below is the SAU5's, the SAU3's and the SAU8's.
  tools/sau_catalog.py finds PBU2_$MAP and PBU2_$UNMAP different on
  each of the SAU3..SAU8, the DMA entries real on the SAU7 and SAU8 (the
  SAU3..SAU6 share the SAU5's stubs), and PBU_$WAIT in four families
  (the SAU3's is the SAU5's); the code segments
  differ in size (0x450 on the SAU3, 0x434 on the SAU4, 0x44C on the
  SAU5, 0x42C on the SAU6, 0xA84 on the SAU7, 0x5F4 on the SAU8).  The
  SAU7's DMA entries keep a mapping record per unit (PBU_$MAPPED_INFO,
  its 0xA0C-byte data segment) and are not the SAU8's. }

var
  unused_00: integer32;                         { +0x0: stand-in }

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order. }
define
  pbu_$dma_start;
  pbu_$dma_stop;
  pbu_$dma_status;
  pbu2_$dma_start;
  pbu2_$dma_stop;
  pbu2_$map;
  pbu2_$unmap;
  pbu_$wait;
  pbu_$dcte_int_ptr;
  pbu_$vme_disable_count;

{ ---- PBU_WIRED_PROC ---- }
%include 'pbu/map_check_unit.pas';          { pbu_map_check_unit }
%include 'pbu/map_owned_ppn.pas';           { pbu_map_owned_ppn }
%if pbu_atbus_units %then
%include 'pbu/map_dma_error.pas';           { pbu_map_dma_error }
%endif
%include 'pbu/dma_start.pas';               { PBU_$DMA_START }
%include 'pbu/dma_stop.pas';                { PBU_$DMA_STOP }
%include 'pbu/dma_status.pas';              { PBU_$DMA_STATUS }
%include 'pbu/pbu2_dma_start.pas';          { PBU2_$DMA_START }
%include 'pbu/pbu2_dma_stop.pas';           { PBU2_$DMA_STOP }
%include 'pbu/pbu2_map.pas';                { PBU2_$MAP }
%include 'pbu/pbu2_unmap.pas';              { PBU2_$UNMAP }
%include 'pbu/wait.pas';                    { PBU_$WAIT }
%endif
