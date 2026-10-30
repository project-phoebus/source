{ route/route.ins.pas - ROUTE_ (network routing), for the Domain Pascal
  tree.

  The statuses, the port record and its parts, the port pointer table,
  the module variables other units read, and the routines' headings.  No
  customer insert file declares these.  Include base/base.ins.pas,
  ec/ec.ins.pas and pkt/pkt.ins.pas before it.
}

const
  { status_$internet_network_port_not_open, 16#002B0001 ("network port
    not open", stcode.db.10.2). }
  status_$internet_network_port_not_open = 16#002B0001;

  { status_$route_illegal_op_for_port_type, 16#002B0009 ("operation not
    legal on this port type", stcode.db.10.2). }
  status_$route_illegal_op_for_port_type = 16#002B0009;

  { The ROUTE statuses ("OS / internet routing", stcode.db.10.2, its
    texts): 16#002B0002 "buffer queue for user port is full", 16#002B0004
    "can not create/delete that port type", 16#002B0006 "routing service
    type not recognized", 16#002B000C "user network checksum failed",
    16#002B000D "bad packet length from user network", 16#002B000E
    "unable to create through-traffic queue", 16#002B0011 "routing not
    allowed at port with 0 network ID".  16#002B0012, 16#002B0013 and
    16#002B0014 are past the end of the module's table (no text). }
  status_$route_queue_full = 16#002B0002;
  status_$internet_illegal_port_type = 16#002B0004;
  status_$route_service_type_bad = 16#002B0006;
  status_$route_checksum_error = 16#002B000C;
  status_$route_bad_packet_format = 16#002B000D;
  status_$route_cant_create_thru_queue = 16#002B000E;
  status_$route_no_routing_zero_network = 16#002B0011;
  status_$route_invalid_ec_type = 16#002B0012;
  status_$route_create_flag_required = 16#002B0013;
  status_$route_queue_length_too_large = 16#002B0014;

  { The members of ROUTE_$SERVICE's operation set (route_$service_ops_t
    below). }
  service_op_set_network = 0;
  service_op_set_status = 1;
  service_op_create_port = 2;
  service_op_close_port = 3;
  service_op_user_port = 5;

  { The largest packet ROUTE_$OUTGOING hands a user, its 4-byte check word
    plus 0x7FC bytes. }
  route_$max_packet_data = 16#7FC;

  { The user packet's check word when it is not summed, and the sum's
    starting value. }
  checksum_magic = 16#0DEC0DED;

type
  { A routing port, 0x5C bytes, the stride of the ROUTE_$PORT array
    (NET_PORT_TABLE is 8 * 0x5C bytes).
    - network at +0; driver_info, the driver record's address at +0x48.
    - active, the port's status word; port_type and socket, the words at
      +0x2E and +0x30.  socket is integer, compared sign-extended.
    - part_34, the bytes from 0x34 to 0x47: queue_len, port_ec (the
      port's eventcount) and driver_stats (its ROUTE_$USER_STAT record),
      or as two words, a variant record (ref 3.10.3).
    - From 0x4C four longwords; the third and fourth count packets put
      and forwarded.  A second view, a variant part, has the 6-byte
      clock at +0x4E and the two counters as one record
      (route_$port_counts_t below); the word at +0x4C is unused_4c.
    - The bytes from 0x04 to 0x2B: n_link_addrs, n_net_addrs, link_addr
      and xns_addr, an array from 0 at 0x20 with room for one element
      before active (n_net_addrs is 1). }
  route_$user_stat_ptr_t = ^route_$user_stat_t;

  { The two records the port holds at 0x08, 0x20.

    route_$link_addr_t, 0x18 bytes: the port's own link-level address, a
    count of address words and the words, indexed from 0
    (mac_os/mac_os.ins.pas declares mac_os_$link_addr_t as this type).

    route_$xns_addr_t, 12 bytes: an XNS endpoint, the network, the host's
    three words and the socket (rip/rip.ins.pas's names but host's: the
    host is an array of words here). }
  route_$link_addr_t = record
    n_words: integer;                     { 0x00 }
    addr: array[0..10] of integer;        { 0x02 }
  end;

  route_$xns_addr_t = record
    network: integer32;                   { 0x00 }
    host: array[0..2] of pinteger;        { 0x04 }
    socket: pinteger;                     { 0x0A }
  end;

  route_$port_part_t = record
    case integer of
      1: (queue_len: integer32;                 { 0x34 }
          port_ec: ec_$eventcount_t;            { 0x38 }
          driver_stats: route_$user_stat_ptr_t); { 0x44 }
      2: (unused_34: integer;                   { 0x34 }
          queue_length: integer);               { 0x36 }
  end;

  { The two counters at +0x54 as one 8-byte record (asknode/
    asknode_info.ins.pas).  The names are route_$port_t's own. }
  route_$port_counts_t = record
    stat_long_54: integer32;              { 0x00 }
    forward_count: integer32;             { 0x04 }
  end;

  route_$port_t = record
    network: integer32;                   { 0x00 }
    n_link_addrs: integer;                { 0x04 }
    n_net_addrs: integer;                 { 0x06 }
    link_addr: route_$link_addr_t;        { 0x08 }
    xns_addr: array[0..0] of route_$xns_addr_t;  { 0x20 }
    active: integer;                      { 0x2C }
    port_type: integer;                   { 0x2E }
    socket: integer;                      { 0x30 }
    unused_32: integer;                   { 0x32 }
    part_34: route_$port_part_t;          { 0x34 }
    driver_info: integer32;               { 0x48 }
    case integer of
      1: (long_4c: integer32;             { 0x4C }
          clock_50: time_$clockh_t;       { 0x50 }
          stat_long_54: integer32;        { 0x54 }
          forward_count: integer32);      { 0x58 }
      2: (unused_4c: integer;             { 0x4C }
          clock_4e: time_$clock_t;        { 0x4E }
          counts: route_$port_counts_t);  { 0x54..0x5B }
  end;
  route_$port_ptr_t = ^route_$port_t;

  { A user port's statistics record, 0x90 bytes: byte 0 is its in-use
    Domain boolean (the two views of the first byte are a variant), the
    byte after it a char of its own.  The counters from 2: a put into a
    deeper queue than 32 at 2, a failed put at 6, and a put at depth d in
    bucket d, from 0xA, 33 buckets, 0..32, to 0x8E; the record's last
    word is unused_8e.  The two longwords are also one 8-byte record
    (route_$user_counts_t below). }
  route_$user_counts_t = record
    deep_queue_puts: integer32;           { 0x00 }
    failed_puts: integer32;               { 0x04 }
  end;

  route_$user_stat_t = record
    case integer of
      1: (in_use: boolean;                { 0x00 }
          unused_01: char;                { 0x01 }
          counts: route_$user_counts_t;   { 0x02 }
          queue_depth: array[0..32] of integer32;  { 0x0A }
          unused_8e: integer);            { 0x8E }
      2: (bytes: array[0..143] of char);
  end;

  { The 12-byte port summary ROUTE_$SHORT_PORT fills in and
    ROUTE_$SERVICE reads its request out of; its callers' locals are
    0x38 bytes, so the record type is 0x38 bytes, its last 0x2C named by
    nothing the image shows (unused_0c).  socket is integer
    (route_$port_t's, above). }
  route_$short_port_t = record
    network: integer32;                   { 0x00 }
    status: integer;                      { 0x04 }
    port_type: integer;                   { 0x06 }
    socket: integer;                      { 0x08 }
    queue_length: pinteger;               { 0x0A }
    unused_0c: array[16#0C..16#37] of char;  { 0x0C }
  end;

  { ROUTE_$SERVICE's operation word, a set (3 is close port). }
  route_$service_ops_t = set of 0..15;

  { The packet a routing port's user hands ROUTE_$INCOMING and gets from
    ROUTE_$OUTGOING: a check word at 0, the packet's header from 4, its
    data after the header; also read as bytes from 0, unsigned
    (pkt/pkt.ins.pas pkt_$byte_t), a variant (ref 3.10.3).  The bound:
    the check word plus 0x7FC bytes (route_$max_packet_data above). }
  route_$user_pkt_t = record
    case integer of
      1: (checksum: integer32;            { 0x00 }
          hdr: pkt_$hdr_t);               { 0x04 }
      2: (bytes: array[0..2047] of pkt_$byte_t);
  end;

  { ROUTE_$OUTGOING's next hop for the user (the 20-bit network address
    and a flag): the node, a longword, and at 4 a boolean, the packet's
    broadcast bit. }
  route_$nexthop_ret_t = record
    node: integer32;                      { 0x00 }
    broadcast: boolean;                   { 0x04 }
  end;

var
  { ROUTE_$PORTP (map symbol, +0x04 of ROUTE's wired block): the eight
    port pointers, from 0. }
  route_$portp: extern array[0..7] of route_$port_ptr_t;

{ ROUTE_$PORT is the overlay section NET_PORT_TABLE (`var (name)', ref
  3.14), its own var part; route/route_wired.pas defines it with the
  image's initial values. }
var (net_port_table)
  { ROUTE_$PORT (map symbol, the first of the map's NET_PORT_TABLE
    section, with NETWORK_$ME and the DCTE labels at the same address):
    the eight port records, from 0. }
  route_$port: extern array[0..7] of route_$port_t;

var

  { ROUTE_$SOCK (map symbol in ROUTE's wired block): the routing socket,
    -1 for none. }
  route_$sock: extern integer;

  { ROUTE_$Q_OFLO (map symbol, RTWIRED_DATA): the count of packets the
    routing socket refused (NET_IO counts them). }
  route_$q_oflo: extern integer32;

  { ROUTE_$USER_STAT (map symbol, RTWIRED_DATA): the four user ports'
    statistics records, from 1. }
  route_$user_stat: extern array[1..4] of route_$user_stat_t;

var
  { ROUTE_$STD_N_ROUTING_PORTS (map symbol in ROUTE's wired block): the
    number of routing ports of the standard IDP routing.  ROUTE_$STD_
    TOO_FAR and ROUTE_$STD_MISROUTE (map symbols, RTWIRED_DATA): the
    counts of forwarded IDP packets dropped for their hop count and for
    the missing routing. }
  route_$std_n_routing_ports: extern integer;
  route_$std_too_far: extern integer32;
  route_$std_misroute: extern integer32;

var
  { The map symbols of ROUTE's three data blocks not declared above,
    each defined by the module file of its block (route/README.md
    has the layouts).

    ROUTE_WIRED's block (WIRED_DATA; route/route_wired.pas):
    - ROUTE_$SOCK_ECVAL: the routing socket's eventcount value
      ROUTE_$PROCESS waits for;
    - ROUTE_$CONTROL_ECVAL, ROUTE_$CONTROL_EC: the routing process's
      control eventcount and its awaited value;
    - ROUTE_$N_ROUTING_PORTS: the number of routing ports of the Domain
      routing;
    - ROUTE_$ROUTING: the router runs.

    ROUTE_UNWIRED's block (.DATA; route/route_unwired.pas):
    - ROUTE_$START_TIME: TIME_$CURRENT_CLOCKH when the routing started.

    ROUTE_RTWIRED's block (RTWIRED_DATA; route/route_rtwired.pas):
    - ROUTE_$WIRED_PAGES: the wired pages of the routing area, ten,
      from 1;
    - ROUTE_$Q_DEPTH: the forwarded packets by the routing socket's
      queue depth, from 0;
    - ROUTE_$STD_DLEN_ERR .. ROUTE_$PKTS_ROUTED: the forwarding counters;
    - ROUTE_$NETBUF_ALLOC: the page counts of the routing socket;
    - ROUTE_$N_WIRED_PAGES, ROUTE_$N_USER_PORTS: the counts of wired
      pages and of open user routing ports;
    - ROUTE_$PID: the routing process;
    - ROUTE_$USER_CHECKSUM: ROUTE_$OUTGOING sums the packet when it is
      set.
    The names are the map's. }
  route_$sock_ecval: extern integer32;
  route_$control_ecval: extern integer32;
  route_$control_ec: extern ec_$eventcount_t;
  route_$n_routing_ports: extern integer;
  route_$routing: extern boolean;

  route_$start_time: extern time_$clockh_t;

  route_$wired_pages: extern array[1..10] of integer32;
  route_$q_depth: extern array[0..128] of integer32;
  route_$std_dlen_err: extern integer32;
  route_$std_pkts_routed: extern integer32;
  route_$dlen_err: extern integer32;
  route_$too_far: extern integer32;
  route_$misroute: extern integer32;
  route_$pkts_routed: extern integer32;
  route_$netbuf_alloc: extern integer;
  route_$n_wired_pages: extern integer;
  route_$n_user_ports: extern integer;
  route_$pid: extern pinteger;
  route_$user_checksum: extern boolean;

  { The wired routing area's markers (map symbols): RTWIRED_PROC_START,
    the first word of the RTWIRED_CODE section, and RTWIRED_DATA_END,
    one past ROUTE_RTWIRED's block.  Labels the build places, as PEB's
    (peb/peb.ins.pas): extern chars, of which only the address is used. }
  rtwired_proc_start: extern char;
  rtwired_data_end: extern char;

{ Routine headings, in map order: ROUTE_WIRED (WIRED_PROC),
  ROUTE_UNWIRED (.TEXT) and ROUTE_RTWIRED (RTWIRED_CODE).  The bodies
  repeat the full headings (ref 7.3.4, Method 2). }

{ ROUTE_$FIND_PORT - the index of the open port of a type and socket. }
function route_$find_port(port_type: integer; socket: integer32): integer;
  options(extern, val_param);

{ ROUTE_$FIND_PORTP - the open port of a type and socket. }
function route_$find_portp(network: integer; socket: integer32): route_$port_ptr_t;
  options(extern, val_param);

{ ROUTE_$SHORT_PORT - the 12-byte summary of a routing port. }
procedure route_$short_port(in port: route_$port_t;
                            out short_info: route_$short_port_t);
  extern;

{ ROUTE_$GET_EC - an eventcount of a user routing port. }
procedure route_$get_ec(in port_info: route_$short_port_t;
                        in ec_type: integer;
                        out ec_ret: ec2_$ptr_t;
                        out status_ret: status_$t);
  extern;

{ ROUTE_$SERVICE - apply one routing-service request to one port. }
procedure route_$service(in operation: route_$service_ops_t;
                         in out port_info: route_$short_port_t;
                         out status_ret: status_$t);
  extern;

{ ROUTE_$SHUTDOWN - close or take down every open routing port. }
procedure route_$shutdown; extern;

{ ROUTE_$READ_USER_STATS - a user routing port's statistics. }
procedure route_$read_user_stats(var socket: univ pinteger;
                                 stats_buf: univ_ptr;
                                 max_len: integer;
                                 out length_ret: integer;
                                 out status_ret: status_$t);
  options(extern, val_param);

{ ROUTE_$PROCESS - the routing process. }
procedure route_$process; extern;

{ ROUTE_$INCOMING - a packet from a user routing port into the network. }
procedure route_$incoming(in port_info: route_$short_port_t;
                          in packet_data: route_$user_pkt_t;
                          in length: pinteger;
                          out status_ret: status_$t);
  extern;

{ ROUTE_$OUTGOING - a packet from the network out to a user routing port. }
procedure route_$outgoing(in port_info: route_$short_port_t;
                          out nexthop_ret: route_$nexthop_ret_t;
                          out packet_buf: route_$user_pkt_t;
                          out length_ret: integer;
                          out status_ret: status_$t);
  extern;

{ ROUTE_$SEND_USER_PORT - the user routing driver's send entry. }
procedure route_$send_user_port(var socket: pinteger; hdr_pa: integer32;
                                hdr: pkt_$hdr_ptr_t;
                                hdr_len: integer;
                                in data_pages: univ pkt_$data_pages_t;
                                data_va: integer32; data_len: pinteger;
                                in flags: univ integer;
                                out xmit_status: pinteger;
                                out status_ret: status_$t);
  options(extern, val_param);

{ A port's type (route_$port_t's port_type, +0x2E; NET_IO_$CREATE_PORT's
  `case ptype of'; the tests for 2 throughout ROUTE and RIP): local and
  routing.  ROUTE_$GET_EC's eventcount key (its
  `case ec_type of'): 0 the socket's eventcount, 1 the port's.  No
  Apollo insert declares them. }
const
  route_$port_type_local = 1;
  route_$port_type_routing = 2;

  route_$ec_socket = 0;
  route_$ec_port = 1;

{ Port type 0 is the ring's: RING_$INIT creates its port with it,
  `net_io_$create_port(0, ...)' (ring/init.pas), ASKNODE_$INTERNET_INFO
  reads RING_$DATA's counters for a port of type 0, and
  NET_IO_$BOOT_DEVICE gives a ring boot (devices 2, 3) boot port type 0.
  Types 4 and 5 (NET_IO_$BOOT_DEVICE's devices 6 and
  8; PKT_$LIKELY_TO_ANSWER's ping test on type 4) come from user-space
  drivers through ROUTE_$SERVICE's port_info; nothing in the image says
  what they are, so they stay numbers. }
const
  route_$port_type_ring = 0;
