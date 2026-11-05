{ ETHERNET_$RCV0 - unit 0's receive process.

  Image addresses:
    sau6  0x7808B084  ETHERNET_$RCV0
    sau7  0x3C49562A  ETHERNET_$RCV0
    sau8  0x03C88E26  ETHERNET_$RCV0
    sau9  0x3C484A4C  ETHERNET_$RCV0

  - A process entry point of the driver's receive-process table:
    ethernet_rcv_process for unit 0.

  Status stored: none.
}

procedure ethernet_$rcv0;
begin
  ethernet_rcv_process(0);
end;
