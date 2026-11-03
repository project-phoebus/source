{ RING_8025_$RCV0 - unit 0's receive process.

  Image addresses:
    sau8  0x03C8D6E6  RING_8025_$RCV0
    sau9  0x3C4893DE  RING_8025_$RCV0

  - The process entry point ring_8025_start_unit creates for unit 0:
    ring_8025_rcv_process for unit 0.

  Status stored: none.
}

procedure ring_8025_$rcv0;
begin
  ring_8025_rcv_process(0);
end;
