{ ethernet/ethernet.ins.pas - ETHERNET routine headings, for the Domain
  Pascal tree.

  The ETHERNET module (ethernet/ethernet.pas), the Ethernet controller
  driver.  Where the driver is configured out (the SAU2) only
  ETHERNET_$INIT is left.  With `ethernet_driver' (base/config.ins.pas)
  the driver of the AT-bus Ethernet adapter the SAU9 (DN2500) has: a 3Com
  3C505 (EtherLink Plus), an adapter with its own processor that the host
  talks to through command blocks passed a byte at a time and packets
  passed a word at a time (ethernet/ethernet_3c505.ins.pas).  Apollo's
  customer insert files of SR10.2 declare nothing of ETHERNET.  Include
  base/base.ins.pas, ml/ml.ins.pas and io/io.ins.pas (dcte_t) before it.
}

{ ETHERNET_$INIT - initialize an Ethernet controller. }
function ethernet_$init(var dcte: dcte_t): integer32; extern;
