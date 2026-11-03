{ RING_8025_$RCV1 - unit 1's receive process.

  Image addresses:
    sau8  0x03C8D702  RING_8025_$RCV1
    sau9  0x3C4893FA  RING_8025_$RCV1

  - The process entry point ring_8025_start_unit creates for unit 1:
    ring_8025_rcv_process for unit 1.

  Status stored: none.
}

procedure ring_8025_$rcv1;
begin
  ring_8025_rcv_process(1);
end;
