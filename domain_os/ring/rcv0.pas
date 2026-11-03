{ RING_$RCV0 - the receive process of unit 0.

  Image addresses:
    sau2  0x00E76642  RING_$RCV0
    sau4  0x0F883EC2  RING_$RCV0
    sau3  0x00E77E32  RING_$RCV0
    sau5  0x00E7D8DA  RING_$RCV0
    sau8  0x03C82F30  RING_$RCV0

  - It runs RING_$RCV_FROM_UNIT_PRIV for unit 0, which never returns.

  Status stored: none.
}

procedure ring_$rcv0;
begin
  ring_$rcv_from_unit_priv(0);
end;
