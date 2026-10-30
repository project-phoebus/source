{ rip/rip_xns.ins.pas - the RIP_ heading that needs XNS's types, for the
  Domain Pascal tree.

  RIP_$STD_DEMUX's heading, apart from rip/rip.ins.pas because it needs
  xns/xns.ins.pas, which most of rip/rip.ins.pas's includers include
  after it.  Only rip/rip_wired.pas includes this file.  Include
  base/base.ins.pas and xns/xns.ins.pas before it.
}

{ RIP_$STD_DEMUX - queue a packet of the standard IDP channel on RIP's
  socket. }
procedure rip_$std_demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                         in port_socket: integer; in mac_broadcast: boolean;
                         out status: status_$t); extern;
