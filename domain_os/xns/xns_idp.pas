{ xns/xns_idp.pas - the XNS_IDP module, the XNS internet datagram
  protocol: its channels and ports, the OS and user calls that open,
  close, send and receive on a channel, and the demultiplexing of
  received IDP packets.

  Image addresses:
    sau2  0x00E2B314  XNS_IDP data (WIRED_DATA, 0x53C bytes)

  One compilation unit: the map's XNS_IDP code segments in WIRED_PROC
  (0x14C4 bytes: the module-local helpers, XNS_IDP_$OS_OPEN ..
  XNS_IDP_$REGISTER_ADDR) and in OS_INIT_PROC (0xD8 bytes,
  XNS_IDP_$INIT), and its data segment in WIRED_DATA (0x53C bytes, with
  the map symbol XNS_IDP_$PORT_TABLE).

  The checksum engine, the XNS_IDP_ASM data segment, is hand assembly
  (xns/m68k/idp_checksum.s).

  The heading: `module xns_idp, wired_proc, wired_data;' (PKT's shape,
  pkt/pkt.pas); XNS_IDP_$INIT is headed `[section(os_init_proc,
  os_init_data)]' and reaches the block by its address.

  The data, 0x53C bytes, all zero in the image:

    +0x000  xns_idp_$packets_sent       4
    +0x004  xns_idp_$packets_received   4
    +0x008  xns_idp_$packets_dropped    4
    +0x00C  unused_0c                   4  a stand-in (see the TODO)
    +0x010  xns_idp_$addr_port        4*2  the registered addresses'
                                           ports, from 0

    +0x018  unused_18                   8  a stand-in (see the TODO)
    +0x020  xns_idp_$addrs            4*6  the registered host addresses,
                                           from 0
    +0x038  unused_38                   8  a stand-in (see the TODO)
    +0x040  XNS_IDP_$PORT_TABLE    8*0x0C  defined; the ports' state

    +0x0A0  xns_idp_$channels     16*0x48  the channels, from 0
    +0x520  xns_idp_$lock            0x12  the exclusion lock
    +0x532  unused_532                  2  a stand-in
    +0x534  xns_idp_$open_channels      2  compared unsigned: pinteger
    +0x536  xns_idp_$next_socket        2  compared unsigned: pinteger

    +0x538  xns_idp_$registered_count   2  the last registered address's
                                           index, tested signed
    +0x53A  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each (xns/<name>.pas), included
  below in image order: the helpers (xns/add_port.pas ..
  xns/is_broadcast_addr.pas), then the globals.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/xns/xns_idp.pas.  Check: tools/pascal_check.sh.
}

{ TODO(pascal) 20 bytes of the XNS_IDP block no object explains

  +0x00C (4), +0x018 (8) and +0x038 (8) are addressed by no instruction
  and named by nothing: the stand-ins unused_0c, unused_18, unused_38.
  Read with the 8-byte alignment lead (objects of 8 bytes or more at
  multiples of 8 from the block) and tables of five entries, addr_port[0..4]
  (10 bytes) at +0x10 and addrs[0..4] (30 bytes) at +0x20, every open byte
  is that alignment's (+0x0C after the counters, +0x1A..+0x1F,
  +0x3E..+0x3F); but only four entries are ever used (XNS_IDP_$REGISTER_ADDR
  refuses a fifth), and the block is at 4 mod 8 as an address. }

module xns_idp, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'mac/mac.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  xns_idp_$packets_sent: integer32;                     { +0x000, zero }
  xns_idp_$packets_received: integer32;                 { +0x004, zero }
  xns_idp_$packets_dropped: integer32;                  { +0x008, zero }
  unused_0c: integer32;                                 { +0x00C, stand-in }
  xns_idp_$addr_port: array[0..3] of integer;           { +0x010, zero }
  unused_18: array[0..3] of integer;                    { +0x018, stand-in }
  xns_idp_$addrs: array[0..3] of xns_$host_t;           { +0x020, zero }
  unused_38: array[0..3] of integer;                    { +0x038, stand-in }

define
  xns_idp_$port_table;                                  { +0x040, zero }

var
  xns_idp_$channels: array[0..15] of xns_$channel_t;    { +0x0A0, zero }
  xns_idp_$lock: ml_$exclusion_t;                       { +0x520, zero }
  unused_532: integer;                                  { +0x532, stand-in }
  xns_idp_$open_channels: pinteger;                     { +0x534, zero }
  xns_idp_$next_socket: pinteger;                       { +0x536, zero }
  xns_idp_$registered_count: integer;                   { +0x538, zero }

define
  xns_idp_$os_open;
  xns_idp_$os_close;
  xns_idp_$os_send;
  xns_idp_$os_demux;
  xns_idp_$os_add_port;
  xns_idp_$os_delete_port;
  xns_idp_$open;
  xns_idp_$close;
  xns_idp_$send;
  xns_idp_$demux;
  xns_idp_$receive;
  xns_idp_$proc2_cleanup;
  xns_idp_$get_port_info;
  xns_idp_$get_stats;
  xns_idp_$register_addr;
  xns_idp_$init;

{ ---- WIRED_PROC ---- }
%include 'xns/add_port.pas';                { xns_$add_port }
%include 'xns/delete_port.pas';             { XNS_$DELETE_PORT }
%include 'xns/find_socket.pas';             { XNS_$FIND_SOCKET }
%include 'xns/get_checksum.pas';            { XNS_$GET_CHECKSUM }
%include 'xns/is_broadcast_addr.pas';       { xns_$is_broadcast_addr }
%include 'xns/idp_os_open.pas';             { XNS_IDP_$OS_OPEN }
%include 'xns/idp_os_close.pas';            { XNS_IDP_$OS_CLOSE }
%include 'xns/idp_os_send.pas';             { XNS_IDP_$OS_SEND }
%include 'xns/idp_os_demux.pas';            { XNS_IDP_$OS_DEMUX }
%include 'xns/idp_os_add_port.pas';         { XNS_IDP_$OS_ADD_PORT }
%include 'xns/idp_os_delete_port.pas';      { XNS_IDP_$OS_DELETE_PORT }
%include 'xns/idp_open.pas';                { XNS_IDP_$OPEN }
%include 'xns/idp_close.pas';               { XNS_IDP_$CLOSE }
%include 'xns/idp_send.pas';                { XNS_IDP_$SEND }
%include 'xns/idp_demux.pas';               { XNS_IDP_$DEMUX }
%include 'xns/idp_receive.pas';             { XNS_IDP_$RECEIVE, xns_$copy_packet_data }
%include 'xns/idp_proc2_cleanup.pas';       { XNS_IDP_$PROC2_CLEANUP }
%include 'xns/idp_get_port_info.pas';       { XNS_IDP_$GET_PORT_INFO }
%include 'xns/idp_get_stats.pas';           { XNS_IDP_$GET_STATS }
%include 'xns/idp_register_addr.pas';       { XNS_IDP_$REGISTER_ADDR }

{ ---- OS_INIT_PROC ---- }
%include 'xns/idp_init.pas';                { XNS_IDP_$INIT }
