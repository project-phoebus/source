{ io/io_desc.pas - the IO_DESC module, the units' I/O descriptors.

  Image addresses:
    sau8  0x03C2EBB8  IO_DESC data (WIRED_DATA, 0x160 bytes)
    sau9  0x3C430DF4  IO_DESC data (WIRED_DATA, 0x1C0 bytes)

  A map module of data only, `module io_desc, , wired_data;': the IO_DESC
  segment in WIRED_DATA, after IO_'s block and before DCTES.  Each
  descriptor is what a unit's driver hands IO_$ACQUIRE and IO_$MAP_CSR
  (io/io.ins.pas io_$acquire_rec_t, 0x20 bytes here with the pad word):
  the interrupt vector, the CSR pages' VA, their bus address and count,
  the tag, the bus (4 the system bus, 3 the AT bus) and the attributes.
  The first longword links a unit's second descriptor (the SCSI
  controller's DMA interrupt, the rings' second CSR window), nil
  elsewhere.  The DCTEs reach them through their disk_dinit cells.

  The SAU9's descriptors, each with its driver's part
  (base/config.ins.pas): the SCSI controller (`scsi_driver'), the four
  16550 lines (`sio16550_lines'), the two 802.5 rings
  (`ring_8025_driver'), the two Ethernets (`ethernet_driver') and the two
  rings (`ring8_controller').  The CSR VAs are the IODEFS pages
  (arch/m68k/sau9/iodefs.s); RING2_IO_DESC holds RING1's two pages and
  RING1_IO_DESC RING2's, as in the image.

  The SAU8's: the two 802.5 rings, the cartridge tape (`ct_qic02'), the
  two Ethernets, the two rings, the floppy (`floppy_disk') and the
  Winchester controller (`winchester_ctlr'), all on the AT bus.  With
  the part io_descriptors, empty elsewhere (the SAU7's IO_DESC, 0x1A0
  bytes, not compared).

  Check: tools/pascal_check.sh (which finds this file by its module
  heading).
}
module io_desc, , wired_data;

%include 'base/base.ins.pas';
%if io_descriptors %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';

type
  { A descriptor: io_$acquire_rec_t with its link and the CSR VA as
    pointers (dpc takes `addr' for a univ_ptr cell), and the pad word
    that makes the records 0x20 apart. }
  io_desc_csr_t = record
    va: univ_ptr;                         { 0x00 }
    pa: linteger;                         { 0x04 }
    pages: integer;                       { 0x08 }
    has_csr: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;
  io_desc_t = record
    next: univ_ptr;                       { 0x00 }
    int: io_$int_info_t;                  { 0x04 }
    csr: io_desc_csr_t;                   { 0x0C }
    tag: integer;                         { 0x18 }
    bus: integer;                         { 0x1A }
    attrs: io_$attr_t;                    { 0x1C }
    unused_1e: integer;                   { 0x1E }
  end;

var
  { The I/O pages the descriptors map (map symbols of IODEFS).  Only
    their addresses are used. }
%if scsi_driver %then
  scsi: extern char;
%endif
%if sio16550_lines %then
  sio0, sio1, sio2, sio3: extern char;
%endif
%if ring_8025_driver %then
  ring_8025_1, ring_8025_2: extern char;
%endif
%if ct_qic02 %then
  tape: extern char;
%endif
%if ethernet_driver %then
  ethernet1, ethernet2: extern char;
%endif
%if ring8_controller %then
  ring1, ring1a, ring2, ring2a: extern char;
%endif
%if floppy_disk %then
  flop: extern char;
%endif
%if winchester_ctlr %then
  win: extern char;
%endif

{ The module's objects (ref 7.2.2, Method 2): declared here, defined
  below in the order of the block, so a first descriptor's link can name
  the second one.  The second descriptors (the SCSI controller's DMA
  interrupt, the rings' second CSR windows) have no map names. }
var
%if scsi_driver %then
  scsi9_io_desc: extern io_desc_t;
  scsi9_dma_io_desc: extern io_desc_t;
%endif
%if sio16550_lines %then
  sio3_io_desc: extern io_desc_t;
  sio2_io_desc: extern io_desc_t;
  sio1_io_desc: extern io_desc_t;
  sio0_io_desc: extern io_desc_t;
%endif
%if ring_8025_driver %then
  ring_8025_2_io_desc: extern io_desc_t;
  ring_8025_1_io_desc: extern io_desc_t;
%endif
%if ct_qic02 %then
  tape_io_desc: extern io_desc_t;
%endif
%if ethernet_driver %then
  ethernet2_io_desc: extern io_desc_t;
  ethernet1_io_desc: extern io_desc_t;
%endif
%if ring8_controller %then
  ring2_io_desc: extern io_desc_t;
  ring2_io_desc_b: extern io_desc_t;
  ring1_io_desc: extern io_desc_t;
  ring1_io_desc_b: extern io_desc_t;
%endif
%if floppy_disk %then
  flp_io_desc: extern io_desc_t;
%endif
%if winchester_ctlr %then
  win_io_desc: extern io_desc_t;
%endif

define
%if scsi_driver %then
  scsi9_io_desc :=  { +0x000 }
    [next := addr(scsi9_dma_io_desc),
     int := [id := [vector := 16#A5], has_int := true],
     csr := [va := addr(scsi), pa := 0, pages := 1, has_csr := true],
     tag := 2, bus := 4];
  scsi9_dma_io_desc :=  { +0x020 }
    [next := nil,
     int := [id := [vector := 16#A4], has_int := true],
     tag := 2, bus := 4];
%endif
%if sio16550_lines %then
  sio3_io_desc :=  { +0x040 }
    [next := nil,
     int := [id := [vector := 16#AF], has_int := true],
     csr := [va := addr(sio3), pa := 0, pages := 1, has_csr := true],
     tag := 2, bus := 4];
  sio2_io_desc :=  { +0x060 }
    [next := nil,
     int := [id := [vector := 16#AE], has_int := true],
     csr := [va := addr(sio2), pa := 0, pages := 1, has_csr := true],
     tag := 2, bus := 4];
  sio1_io_desc :=  { +0x080 }
    [next := nil,
     int := [id := [vector := 16#AD], has_int := true],
     csr := [va := addr(sio1), pa := 0, pages := 1, has_csr := true],
     tag := 2, bus := 4];
  sio0_io_desc :=  { +0x0A0 }
    [next := nil,
     int := [id := [vector := 16#AC], has_int := true],
     csr := [va := addr(sio0), pa := 0, pages := 1, has_csr := true],
     tag := 2, bus := 4];
%endif
%if ring_8025_driver %then
  ring_8025_2_io_desc :=  { +0x0C0 }
    [next := nil,
     int := [id := [vector := 16#0B], has_int := true],
     csr := [va := addr(ring_8025_2), pa := 16#290, pages := 2,
             has_csr := true],
     tag := 2, bus := 3, attrs := [0]];
  ring_8025_1_io_desc :=  { +0x0E0 }
    [next := nil,
     int := [id := [vector := 16#0C], has_int := true],
     csr := [va := addr(ring_8025_1), pa := 16#280, pages := 2,
             has_csr := true],
     tag := 2, bus := 3, attrs := [0]];
%endif
%if ct_qic02 %then
  tape_io_desc :=  { +0x040 on the SAU8 }
    [next := nil,
     int := [id := [vector := 16#05], has_int := true],
     csr := [va := addr(tape), pa := 16#200, pages := 1,
             has_csr := true],
     tag := 2, bus := 3];
%endif
%if ethernet_driver %then
  ethernet2_io_desc :=  { +0x100 }
    [next := nil,
     int := [id := [vector := 16#09], has_int := true],
     csr := [va := addr(ethernet2), pa := 16#310, pages := 1,
             has_csr := true],
     tag := 2, bus := 3];
  ethernet1_io_desc :=  { +0x120 }
    [next := nil,
     int := [id := [vector := 16#0A], has_int := true],
     csr := [va := addr(ethernet1), pa := 16#300, pages := 1,
             has_csr := true],
     tag := 2, bus := 3];
%endif
%if ring8_controller %then
  ring2_io_desc :=  { +0x140 }
    [next := addr(ring2_io_desc_b),
     int := [id := [vector := 16#03], has_int := true],
     csr := [va := addr(ring1), pa := 16#240, pages := 4,
             has_csr := true],
     tag := 2, bus := 3];
  ring2_io_desc_b :=  { +0x160 }
    [next := nil,
     csr := [va := addr(ring1a), pa := 16#340, pages := 4,
             has_csr := true],
     tag := 2, bus := 3];
  ring1_io_desc :=  { +0x180 }
    [next := addr(ring1_io_desc_b),
     int := [id := [vector := 16#03], has_int := true],
     csr := [va := addr(ring2), pa := 16#220, pages := 4,
             has_csr := true],
     tag := 2, bus := 3];
  ring1_io_desc_b :=  { +0x1A0 }
    [next := nil,
     csr := [va := addr(ring2a), pa := 16#320, pages := 4,
             has_csr := true],
     tag := 2, bus := 3];
%endif
%if floppy_disk %then
  flp_io_desc :=  { +0x120 on the SAU8 }
    [next := nil,
     int := [id := [vector := 16#06], has_int := true],
     csr := [va := addr(flop), pa := 16#3F0, pages := 1,
             has_csr := true],
     tag := 2, bus := 3];
%endif
%if winchester_ctlr %then
  win_io_desc :=  { +0x140 on the SAU8 }
    [next := nil,
     int := [id := [vector := 16#0E], has_int := true],
     csr := [va := addr(win), pa := 16#1A0, pages := 1,
             has_csr := true],
     tag := 2, bus := 3];
%endif
%endif
