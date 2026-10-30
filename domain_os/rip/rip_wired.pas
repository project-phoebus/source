{ rip/rip_wired.pas - the RIP_WIRED module: the routing table, its
  lookups and aging, the next hop of a destination, the routes of a
  closing port, the table's update, the standard IDP channel's demux
  routine and its open, and RIP's initialization, with the wired block
  of RIP's state.

  Image addresses:
    sau2  0x00E26258  RIP_WIRED data (WIRED_DATA, 0xC8C bytes)
    sau2  0x00E3502C  RIP_WIRED data (OS_INIT_DATA, 0x4 bytes)

  One compilation unit: the map's RIP_WIRED code segments in WIRED_PROC
  (0x654 bytes, RIP_$NET_LOOKUP .. RIP_$STD_OPEN) and OS_INIT_PROC
  (0x220 bytes, RIP_$INIT), and its data segments in WIRED_DATA (0xC8C
  bytes) and OS_INIT_DATA (4 bytes).  RIP is three map modules
  (rip/README.md); there is no rip/rip.pas.

  The heading: `module rip_wired, wired_proc, wired_data;'
  (route/route_wired.pas's shape).  RIP_$INIT is headed
  `[section(os_init_proc, os_init_data)]': its static is the
  OS_INIT_DATA block, and it reaches the WIRED_DATA block by its
  absolute address.

  The WIRED_DATA block, 0xC8C bytes, zero but where shown:

    +0x000  rip_$route_port          0xA  RIP_$INIT's source for
                                          RIP_$UPDATE_INT
    +0x00A  unused_0a                  6  a stand-in (see the TODO)
    +0x010  XNS_ERROR_$CLIENT_MUTEX 0x12
    +0x022  unused_22                  6  a stand-in
    +0x028  ROUTE_$SERVICE_MUTEX    0x12

    +0x03A  unused_3a                  6  a stand-in
    +0x040  rip_$exclusion          0x12  the RIP lock
    +0x052  unused_52                  2  a stand-in
    +0x054  RIP_$STATS             0x110  1, then zero
    +0x164  RIP_$INFO              0xB00

    +0xC64  RIP_$STD_IDP_CHANNEL       2  16#FFFF: no channel
    +0xC66  RIP_$NS_ANNOUNCEMENT       2  3
    +0xC68  RIP_$BCAST_CONTROL      0x1E  flags [4, 7], routing_type 2,
                                          addr_type 1, protocol 1,
                                          field_0c 16#FFFF, then zero

    +0xC86  RIP_$STD_RECENT_CHANGES    1  false
    +0xC88  RIP_$RECENT_CHANGES        1  false
    +0xC89  (3 bytes: the block's rounding to 4)

  The types are rip/rip.ins.pas's.  The OS_INIT_DATA block (zero) is
  RIP_$INIT's static `request' (2 bytes, rounded to 4).

  The routines, in image order (rip/README.md has the table):
  rip_$lock and rip_$unlock (module-local), RIP_$NET_LOOKUP, RIP_$AGE,
  RIP_$FIND_NEXTHOP, RIP_$PORT_CLOSE, RIP_$UPDATE_INT
  (rip/update_int.pas), RIP_$STD_DEMUX (rip/std_demux.pas) and
  RIP_$STD_OPEN (rip/std_open.pas);
  RIP_$INIT in OS_INIT_PROC.

  Build: dpc -I domain_os domain_os/rip/rip_wired.pas.  Check:
  tools/pascal_check.sh.
}

{ TODO(pascal) 20 bytes of the RIP_WIRED block no object explains

  +0x0A..+0x0F, +0x22..+0x27 and +0x3A..+0x3F (6 bytes each) lie before
  the three 0x12-byte exclusion records at +0x10, +0x28 and +0x40, and
  +0x52..+0x53 before RIP_$STATS at +0x54; no instruction addresses
  them.  The records' places are those of objects of 8 bytes or more put
  at multiples of 8 from the block (whose start is a multiple of 8), the
  first 6 bytes the rest of rip_$route_port's 16 if it is 10
  (RIP_$UPDATE_INT reads 10 bytes); but RIP_$STATS (0x110 bytes) at
  +0x54 and RIP_$INFO (0xB00) at +0x164 are at 4 mod 8, against that
  rule, and 2 bytes before RIP_$STATS are not a word's rounding.  The
  stand-ins hold the places; dpc does not 8-align. }

module rip_wired, wired_proc, wired_data;

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
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';
%include 'rip/rip.ins.pas';
%include 'rip/rip_xns.ins.pas';
%include 'network/network.ins.pas';

const
  { The standard IDP channel RIP_$STD_OPEN opens: XNS's routing
    information socket, 1, and the open flags, the bind-local member
    (xns/xns.ins.pas xns_open_flag_bind_local, bit 1 of the word: 2),
    stored as one longword (app/app.ins.pas's app_std_protocol and
    app_open_flag_bind_local are APP's pair).  The names claim no
    more. }
  rip_std_socket = 1;
  rip_open_flag_bind_local = 2;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  rip_$route_port: rip_$nexthop_t;        { +0x000, zero }
  unused_0a: array[1..3] of integer;      { +0x00A, stand-in }

define
  xns_error_$client_mutex;                { +0x010, zero }

var
  unused_22: array[1..3] of integer;      { +0x022, stand-in }

define
  route_$service_mutex;                   { +0x028, zero }

var
  unused_3a: array[1..3] of integer;      { +0x03A, stand-in }
  rip_$exclusion: ml_$exclusion_t;        { +0x040, zero }
  unused_52: integer;                     { +0x052, stand-in }

define
  rip_$stats := [unused_00 := 1];         { +0x054: 1, then zero }
  rip_$info;                              { +0x164, zero }
  rip_$std_idp_channel := 16#FFFF;        { +0xC64: 16#FFFF }
  rip_$ns_announcement := 3;              { +0xC66: 3 }
  rip_$bcast_control := [flags := [4, 7],
                         routing_type := pkt_$routing_inet,
                         addr_type := pkt_$addr_short, protocol := 1,
                         field_0c := 16#FFFF];
                                          { +0xC68, then zero }
  rip_$std_recent_changes;                { +0xC86, zero }
  rip_$recent_changes;                    { +0xC88, zero }

define
  rip_$net_lookup;
  rip_$age;
  rip_$find_nexthop;
  rip_$port_close;
  rip_$update_int;
  rip_$std_demux;
  rip_$std_open;
  rip_$init;

{ ---- WIRED_PROC ---- }
%include 'rip/lock.pas';                  { rip_$lock }
%include 'rip/unlock.pas';                { rip_$unlock }
%include 'rip/net_lookup.pas';            { RIP_$NET_LOOKUP }
%include 'rip/age.pas';                   { RIP_$AGE }
%include 'rip/find_nexthop.pas';          { RIP_$FIND_NEXTHOP }
%include 'rip/port_close.pas';            { RIP_$PORT_CLOSE }
%include 'rip/update_int.pas';            { RIP_$UPDATE_INT and
                                            its two nested routines }
%include 'rip/std_demux.pas';             { RIP_$STD_DEMUX }
%include 'rip/std_open.pas';              { RIP_$STD_OPEN }

{ ---- OS_INIT_PROC ---- }
%include 'rip/init.pas';                  { RIP_$INIT }
