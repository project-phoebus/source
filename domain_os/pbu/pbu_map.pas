{ pbu/pbu_map.pas - the PBU_MAP module, the PBU's interrupt-level I/O
  map and DMA entries and its wait.

  Image addresses:
    sau3  0x00E8A054  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau4  0x0F897FD8  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau5  0x00E9241C  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau6  0x780A77FC  PBU_MAP data (PBU_WIRED_DATA, 0xC bytes)
    sau7  0x3C4B7148  PBU_MAP data (PBU_WIRED_DATA, 0xA0C bytes)
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

  On the SAU4 0x434 bytes: the SAU3's routines with word I/O map
  entries that are the page number alone (`word_iomap').

  On the SAU8 0x5F4 bytes: three module-local routines (the third,
  pbu_map_dma_error, the AT bus's), the DMA entries driving the AT
  bus's DMA channels (`pbu_atbus_units', `atbus_dma'), PBU2_$MAP and
  PBU2_$UNMAP as stubs (no I/O map space, `io_regions'), PBU_$WAIT.

  On the SAU6 0x42C bytes: the SAU5's routines with the page owners
  from 16#4000 (`mmap_ppns_4000') and pbu_map_owned_ppn's answer masked
  to the I/O map entry's page field (`pbu_iomap_page_mask').

  On the SAU7 0xA84 bytes: the SAU8's module-local routines (the page
  owners from `pbu_ppns_4000') and PBU_$WAIT, the DMA entries reaching
  the buffer through the unit's I/O map space (`pbu_dma_iomap': the
  mappings in PBU_$MAPPED_INFO), and PBU2_$MAP and PBU2_$UNMAP with
  word entries (`word_iomap'); the data segment 0xA0C bytes.

  Without the driver the module compiles to nothing.

  Its code is wired with the PBU page (PBU_$WIRE_PBU): user handlers
  call PBU2_$MAP, PBU2_$UNMAP and the DMA entries through PBU_$TRAP6 at
  interrupt level.  EC2_PBU (pbu/ec2_pbu.pas) follows it in both
  sections.

  Not part of the module: PBU_$PAGE_END, the map's symbol at the
  module's first byte, a marker: the end of the PBU page's hand-written
  part (pbu/sau5/pbu_asm.s, pbu/sau3/pbu_asm.s, pbu/sau4/pbu_asm.s,
  pbu/sau6/pbu_asm.s).

  The data block, 0xC bytes, zero: a longword nothing names, then the
  map's PBU_$DCTE_INT_PTR and PBU_$VME_DISABLE_COUNT, defined variables
  (pbu/pbu.ins.pas).  Nothing in the SAU5 image refers to any of it.
  With `pbu_dma_iomap' the block is 0xA0C bytes:

    +0x000  a longword nothing names
    +0x004  PBU_$MAPPED_INFO, 16 units of 8 channel records, 20 bytes
            each (pbu_$mapped_info_t)
    +0xA04  PBU_$DCTE_INT_PTR
    +0xA08  PBU_$VME_DISABLE_COUNT

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
%if pbu_dma_iomap %then
  pbu_$mapped_info;
%endif
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
