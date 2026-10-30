{ route/route_rtwired.pas - the ROUTE_RTWIRED module: the routing process
  that forwards packets between the routing ports, the user ports' calls
  that take a packet in and give one out, the user driver's send entry,
  and the wired block of the routing statistics.

  Image addresses:
    sau2  0x00E87D80  ROUTE_RTWIRED data (RTWIRED_DATA, 0x4A8 bytes)

  One compilation unit, in one code section and one data section, the
  wired routing area's: the map's ROUTE_RTWIRED code segment in
  RTWIRED_CODE (0x97C bytes, ROUTE_$PROCESS .. ROUTE_$SEND_USER_PORT)
  and its data segment in RTWIRED_DATA (0x4A8 bytes, then
  RTWIRED_DATA_END, the section's end).  RIP's RIP_RTWIRED segments come
  first in both sections.

  The heading: the block's objects are module variables, most of them
  map symbols `define'd here, so `module route_rtwired, rtwired_code,
  rtwired_data;' (scsi/scsi.pas's shape).  ROUTE_UNWIRED reaches the
  block by its address.

  The data, 0x4A8 bytes, zero but the last eight:

    +0x000  ROUTE_$WIRED_PAGES        4*10
    +0x028  ROUTE_$Q_DEPTH          4*0x81
    +0x22C  ROUTE_$STD_DLEN_ERR .. ROUTE_$Q_OFLO  4*9
    +0x250  ROUTE_$NETBUF_ALLOC          2
    +0x252  ROUTE_$N_WIRED_PAGES         2
    +0x254  ROUTE_$N_USER_PORTS          2

    +0x256  ROUTE_$USER_STAT        0x90*4
    +0x496  ROUTE_$PID                   2
    +0x498  ROUTE_$USER_CHECKSUM         1  false
    +0x49A  unused_49a                   2  a stand-in (see the TODO)

    +0x49C  route_$service_id            4  NETWORK_$SET_SERVICE's value
    +0x4A0  route_$ptr_control_ec        4  addr(route_$control_ec),
                                            EC_$WAITN's list of one
    +0x4A4  route_$fwd_timeout           2  1: NET_IO_$SEND's flags
    +0x4A6  route_$packet_seq            2  16#8000: ROUTE_$SEND_USER_
                                            PORT's transmit status

  The routines live in one fragment file each, included below in image
  order.

  Build: dpc -I domain_os domain_os/route/route_rtwired.pas.  Check:
  tools/pascal_check.sh.
}

{ TODO(pascal) 2 bytes of the ROUTE_RTWIRED block no object explains

  +0x49A..+0x49B lie between ROUTE_$USER_CHECKSUM (+0x498) and
  route_$service_id (+0x49C), and no instruction addresses them.  A
  4-byte network_$service_t record is word aligned (dpc puts it at
  +0x49A), so the stand-in unused_49a holds the place. }

module route_rtwired, rtwired_code, rtwired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';
%include 'app/app.ins.pas';
%include 'ring/ringlog.ins.pas';
%include 'wp/wp.ins.pas';

const
  { The module's numbers: the ticks between RIP's broadcasts; the largest
    packet put on a real port; the hop count at which a packet is
    dropped; MAC's frame type (all ROUTE_$PROCESS's). }
  route_$broadcast_interval = 114;
  route_$max_forward_size = 1024;
  route_$max_hop_count = 16;
  route_$mac_frame_type = 16#600;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
define
  route_$wired_pages;                                   { +0x000, zero }
  route_$q_depth;                                       { +0x028, zero }
  route_$std_dlen_err;                                  { +0x22C, zero }
  route_$std_too_far;                                   { +0x230, zero }
  route_$std_misroute;                                  { +0x234, zero }
  route_$std_pkts_routed;                               { +0x238, zero }
  route_$dlen_err;                                      { +0x23C, zero }
  route_$too_far;                                       { +0x240, zero }
  route_$misroute;                                      { +0x244, zero }
  route_$pkts_routed;                                   { +0x248, zero }
  route_$q_oflo;                                        { +0x24C, zero }
  route_$netbuf_alloc;                                  { +0x250, zero }
  route_$n_wired_pages;                                 { +0x252, zero }
  route_$n_user_ports;                                  { +0x254, zero }
  route_$user_stat;                                     { +0x256, zero }
  route_$pid;                                           { +0x496, zero }
  route_$user_checksum;                                 { +0x498, zero }

var
  unused_49a: integer;                                  { +0x49A, stand-in }
  route_$service_id: network_$service_t;                { +0x49C, zero }
  route_$ptr_control_ec: ec_$eventcount_ptr_t := addr(route_$control_ec);
                                                        { +0x4A0 }
  route_$fwd_timeout: integer := 1;                     { +0x4A4 }
  route_$packet_seq: pinteger := 16#8000;               { +0x4A6 }

define
  route_$process;
  route_$incoming;
  route_$outgoing;
  route_$send_user_port;

{ ---- RTWIRED_CODE ---- }
%include 'route/process.pas';               { ROUTE_$PROCESS        }
%include 'route/incoming.pas';              { ROUTE_$INCOMING       }
%include 'route/outgoing.pas';              { ROUTE_$OUTGOING       }
%include 'route/send_user_port.pas';        { ROUTE_$SEND_USER_PORT }
