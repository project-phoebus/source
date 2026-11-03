{ ETHERNET_$RCV1 - unit 1's receive process.

  Image addresses:
    sau8  0x03C88E42  ETHERNET_$RCV1
    sau9  0x3C484A68  ETHERNET_$RCV1

  - A process entry point of the driver's receive-process table:
    ethernet_rcv_process for unit 1.

  Status stored: none.
}

procedure ethernet_$rcv1;
begin
  ethernet_rcv_process(1);
end;
