{ ring/ring_wired.pas - the RING_WIRED module: the ring's wired counters.

  Image addresses:
    sau2  0x00E261AC  RING_WIRED data (WIRED_DATA, 0xAC bytes)
    sau6  0x78029568  RING_WIRED data (WIRED_DATA, 0xAC bytes)
    sau7  0x3C42BDE0  RING_WIRED data (WIRED_DATA, 0xAC bytes)
    sau8  0x03C28254  RING_WIRED data (WIRED_DATA, 0xAC bytes)

  A map module of data only: the map's RING_WIRED data segment in
  WIRED_DATA (0xAC bytes), whose map symbols are RING_$SWDIAG_NODEID ..
  RING_$DATA.  Every object is a map symbol, `define'd here (their
  types in ring/ring.ins.pas); the RING routines reach them by their
  addresses.

  The data, 0xAC bytes:

    +0x00  RING_$SWDIAG_NODEID        4     zero
    +0x04  RING_$SWDIAG_GOODRCV_CNT   4     zero
    +0x08  RING_$SWDIAG_RCVCNT        4     zero
    +0x0C  RING_$RCV_BIPHASE          2     zero
    +0x0E  RING_$RCV_ESB              2     zero

    +0x10  RING_$XMIT_BIPHASE         2     zero
    +0x12  RING_$XMIT_ESB             2     zero
    +0x14  RING_$PAGING_OVERFLOW      2     zero

    +0x16  RING_$SWDIAG_DATA          0x1E  1, then zero
    +0x34  RING_$DATA                 0x78  two statistics records, each
                                            1, then zero

  The heading: no code, so no code section is named, `module
  ring_wired, , wired_data;' (ref 2.2.1 p. 2-10's `name, ,
  data_section' form, hint/hint_wired.pas's).

  Check: tools/pascal_check.sh.
}
module ring_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ring/ring.ins.pas';

define
  ring_$swdiag_nodeid;                             { +0x00, zero }
  ring_$swdiag_goodrcv_cnt;                        { +0x04, zero }
  ring_$swdiag_rcvcnt;                             { +0x08, zero }
  ring_$rcv_biphase;                               { +0x0C, zero }
  ring_$rcv_esb;                                   { +0x0E, zero }
  ring_$xmit_biphase;                              { +0x10, zero }
  ring_$xmit_esb;                                  { +0x12, zero }
  ring_$paging_overflow;                           { +0x14, zero }
  ring_$swdiag_data := [unused_00 := 1];           { +0x16 }
  ring_$data := [[unused_00 := 1], [unused_00 := 1]];
                                                   { +0x34, +0x70 }
