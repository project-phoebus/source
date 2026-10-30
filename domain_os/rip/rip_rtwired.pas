{ rip/rip_rtwired.pas - the RIP_RTWIRED module: RIP's sending, the
  table's broadcast and the router's halt, with their wired block.

  Image addresses:
    sau2  0x00E87D68  RIP_RTWIRED data (RTWIRED_DATA, 0x18 bytes)

  One compilation unit, in the wired routing area's sections
  (route/README.md): the map's RIP_RTWIRED code segment in
  RTWIRED_CODE (0x3EC bytes, RIP_$SEND, RIP_$BROADCAST,
  RIP_$HALT_ROUTER; its start the marker RTWIRED_PROC_START) and its
  data segment in RTWIRED_DATA (0x18 bytes, at RTWIRED_DATA_START).

  The heading: `module rip_rtwired, rtwired_code, rtwired_data;'
  (route/route_rtwired.pas's shape); the block's objects are module
  variables.

  The data, 0x18 bytes, zero but the halt record at +0x10:

    +0x00  rip_$dest_addr          0xC  the destination RIP_$BROADCAST
                                        and RIP_$HALT_ROUTER give
                                        RIP_$SEND
    +0x0C  rip_$send_flags           2  NET_IO_$SEND's flags

    +0x0E  unused_0e                 2  a stand-in (see the TODO)
    +0x10  rip_$halt_data            8  a response with one entry,
                                        network -1 at 16 hops.

  The routines, in image order (rip/README.md has the table):
  RIP_$SEND with its nested routines (rip/send.pas), RIP_$BROADCAST
  (rip/broadcast.pas),
  RIP_$HALT_ROUTER (rip/halt_router.pas).

  Build: dpc -I domain_os domain_os/rip/rip_rtwired.pas.  Check:
  tools/pascal_check.sh.
}

{ TODO(pascal) 2 bytes of the RIP_RTWIRED block no object explains

  +0x0E..+0x0F lie between rip_$send_flags (a word) and the 8-byte halt
  record at +0x10, and no instruction addresses them.  An object of 8
  bytes or more at a multiple of 8 from the block (and from address 0:
  the block's start is one) puts the record there by itself; dpc does not
  8-align, so the stand-in unused_0e holds the place. }

module rip_rtwired, rtwired_code, rtwired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';

type
  { The halt record, 8 bytes: the start of a RIP packet (rip/rip.ins.pas
    rip_$packet_t), the command and one entry.  RIP_$HALT_ROUTER passes
    it to RIP_$SEND's `univ' data with the length 8. }
  rip_$halt_packet_t = record
    command: integer;                     { 0x00 }
    entry: rip_$pkt_entry_t;              { 0x02 }
  end;

  { A pointer to data copied by OS_$DATA_COPY: RIP_$SEND's data and the
    header's payload, pushed for their targets (rip/send.pas;
    xpd/xpd.ins.pas xpd_$data_ptr_t is XPD's). }
  rip_$data_ptr_t = ^os_$data_t;

{ The module's own variables, in the order of the block (above); then
  the routines in map order. }
var
  rip_$dest_addr: route_$xns_addr_t;      { +0x00, zero }
  rip_$send_flags: integer := 0;          { +0x0C: 0 }
  unused_0e: integer;                     { +0x0E, stand-in }
  rip_$halt_data: rip_$halt_packet_t :=
    [command := rip_cmd_response,
     entry := [network := -1, metric := 16]];
                                          { +0x10 }

define
  rip_$send;
  rip_$broadcast;
  rip_$halt_router;

{ ---- RTWIRED_CODE ---- }
%include 'rip/send.pas';                  { RIP_$SEND and its two nested
                                            routines }
%include 'rip/broadcast.pas';             { RIP_$BROADCAST }
%include 'rip/halt_router.pas';           { RIP_$HALT_ROUTER }
