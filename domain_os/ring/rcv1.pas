{ RING_$RCV1 - the receive process of unit 1.

  Image addresses:
    sau2  0x00E7665E  RING_$RCV1
    sau3  0x00E77E4E  RING_$RCV1
    sau5  0x00E7D8EA  RING_$RCV1
    sau8  0x03C82F4C  RING_$RCV1
    sau9  0x3C47EB3E  RING_$RCV1

  - It runs RING_$RCV_FROM_UNIT_PRIV for unit 1, which never returns.

  Status stored: none.
}

procedure ring_$rcv1;
begin
  ring_$rcv_from_unit_priv(1);
end;
