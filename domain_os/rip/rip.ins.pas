{ rip/rip.ins.pas - RIP_ (the routing information protocol), for the
  Domain Pascal tree.

  What the Pascal files use: RIP's constants, statuses, types and map
  symbols, and the headings of its globals.  No customer insert file
  declares them.  Include base/base.ins.pas,
  ml/ml.ins.pas and route/route.ins.pas (RIP_$UPDATE_D's port summary)
  before it.  RIP_$STD_DEMUX's heading, which needs xns/xns.ins.pas, is
  in rip/rip_xns.ins.pas.
}

const
  { A route's hop counts and timeouts: the hop count of an unreachable
    network, stored by RIP_$AGE and RIP_$PORT_CLOSE, and the largest
    RIP_$UPDATE_INT keeps; the ticks a route lives; the ticks a
    withdrawn route ages. }
  rip_infinity = 16#11;
  rip_route_timeout = 16#168;
  rip_aging_timeout = 16#28;

  { A route's states, the two bits of its flags: an empty slot, which
    RIP_$AGE skips; a valid route, an aging one (RIP_$AGE's dispatch); an
    expired one, both bits set. }
  rip_state_unused = 0;
  rip_state_valid = 1;
  rip_state_aging = 2;
  rip_state_expired = 3;

  { The RIP socket and packet: socket 8, RIP_$SERVER's SOCK_$GET, and
    the socket the announcements go to (RIP_$ANNOUNCE_NS); the commands
    in the packet's first word, RIP_$SERVER's compare chain; the most
    entries a packet holds. }
  rip_socket = 8;
  rip_cmd_request = 1;
  rip_cmd_response = 2;
  rip_cmd_name_register = 3;
  rip_max_entries = 16#5A;

  { 16#003C0001, "network unreachable" (stcode.db.10.2, "OS / Routing
    Information Protocol"): RIP_$FIND_NEXTHOP stores
    it. }
  rip_$status_no_route = 16#003C0001;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    xns/xns.ins.pas's xns_$byte_t: a route's port and hop count, widened
    with zeros (rip_$apply_update, RIP_$FIND_NEXTHOP, RIP_$PORT_CLOSE). }
  rip_$byte_t = [byte] 0..255;

  { The 6 bytes of a next hop's host as RIP reads them: the high word,
    then a 20-bit node in the low bits of the longword at 2 (the field's
    unit).  RIP_$TABLE merges a longword into the node in place (a
    packed field's store, the value masked) and reads it; RIP_$UPDATE
    merges its node unmasked; rip_$compare_source reads two (a "no
    shift" read).  The names are those of rip_$dest_addr_t's fields
    (below), which are the same bits at the same offsets. }
  rip_$host_bits_t = packed record
    host_hi: pinteger;                    { 0x00, bits 0..15 }
    unused_06: 0..4095;                   { 0x02, bits 16..27 }
    host_node: 0..16#FFFFF;               { 0x02, bits 28..47 }
  end;

  { A next hop, 10 bytes: a network and a 6-byte
    host address, the low longword at 6 (word aligned by the kernel's
    word rules).  MAC_OS_$ARP takes one by address
    (mac_os/mac_os.ins.pas); MAC_$SEND passes the MAC_OS block's
    broadcast record at +0x8E0, whose bytes are 0 0 0 0 then six 16#FF,
    two zero bytes after them to the block's end.  The host is also read
    as three words, a variant of the same bytes (ref 3.10.3):
    MAC_OS_$ARP tests the words separately, masks the one at 6, and
    copies the three in a `for' loop over a pointer stepped from the
    record with the field's offset as the displacement: an array of
    words from 0 at 4.  host_hi and host_lo stay
    for MAC_OS's block's initializer (mac_os/mac_os.pas); host claims no
    more than "the host's words".  A third view of the same bytes, the
    host as RIP's packed fields (rip_$host_bits_t above): RIP_$TABLE
    merges a node into a next hop's 20-bit field in place, which a
    packed field's store does and an integer's does not.  Each arm is 6
    bytes from 4. }
  rip_$nexthop_t = record
    network: integer32;                   { 0x00 }
    case integer of
      1: (host_hi: pinteger;              { 0x04 }
          host_lo: integer32);            { 0x06 }
      2: (host: array[0..2] of pinteger); { 0x04 }
      3: (host_bits: rip_$host_bits_t);   { 0x04 }
  end;

  { The destination RIP_$FIND_NEXTHOP is asked about, 12 bytes (network,
    host_hi, host_lo at 6, socket).  The PKT
    routines build it in their frames, the network with a longword store
    and only the low 20 bits of host_lo, merged unmasked into the
    longword at 6 (PKT_$BLD_INTERNET_HDR, PKT_$LIKELY_TO_ANSWER): a
    packed record's 20-bit field, its unit the longword at 6, so the record
    is packed; host_lo's high 12 bits and host_hi are not written (stale
    stack bytes).  RIP_$FIND_NEXTHOP reads the network and copies the first
    10 bytes.  host_node names the 20 bits of the node id. }
  rip_$dest_addr_t = packed record
    network: integer32;                   { 0x00 }
    host_hi: pinteger;                    { 0x04 }
    unused_06: 0..4095;                   { 0x06, bits 0..11 }
    host_node: 0..16#FFFFF;               { 0x06, bits 12..31 }
    socket: pinteger;                     { 0x0A }
  end;

  {  A pointer to a next hop:
    RIP_$FIND_NEXTHOP takes the first 10 bytes of its destination as one
    (rip/find_nexthop.pas). }
  rip_$nexthop_ptr_t = ^rip_$nexthop_t;

  { A route's flags, the byte at 0x10 of a route and the byte after it,
    a packed record of one word (at least 16
    bits): the state in the top two bits, read by a mask and a shift (in
    every routine that tests a state), set to 2, to 0 or to 3 on the
    byte or, with the constant in a register for two records, on the
    word (RIP_$NET_LOOKUP), which is why the record is the
    word; set from a variable (RIP_$TABLE_D).  Nothing reads the other
    14 bits. }
  rip_$route_state_t = packed record
    state: 0..3;                          { bits 0..1 }
    unused_bits: 0..16#3FFF;              { bits 2..15 }
  end;

  { A route, 0x14 bytes: when it expires, compared
    signed with TIME_$CLOCKH (RIP_$AGE); the next hop, a 10-byte record
    copied whole (rip_$apply_update); the port's index and the hop
    count, bytes (rip_$byte_t above); the flags (above); a word nothing
    reads, which makes the 0x14 of the entries' stride (below). }
  rip_$route_t = record
    expiration: integer32;                { 0x00 }
    nexthop: rip_$nexthop_t;              { 0x04 }
    port: rip_$byte_t;                    { 0x0E }
    metric: rip_$byte_t;                  { 0x0F }
    flags: rip_$route_state_t;            { 0x10 }
    unused_12: integer;                   { 0x12 }
  end;
  rip_$route_ptr_t = ^rip_$route_t;

  { A routing table entry, 0x2C bytes: the network
    and its two routes, the Domain internet's at 4 and the standard
    (XNS) routing's at 0x18, chosen by the routines' `std' booleans
    (RIP_$UPDATE_INT, through a pointer stepped from the block's start,
    RIP_$INFO at +0x164), indexed from 0 (the `std' flag picks
    routes[1]).  The table's stride is 0x2C (RIP_$NET_LOOKUP's multiply,
    RIP_$AGE's step). }
  rip_$entry_t = record
    network: integer32;                   { 0x00 }
    routes: array[0..1] of rip_$route_t;  { 0x04 }
  end;
  rip_$entry_ptr_t = ^rip_$entry_t;

  { RIP's counters, 0x110 bytes: a word nothing
    addresses, 1 in the image; the packets RIP_$SERVER takes in; the bad
    ones; those with an unknown command; the packets routed to a local
    network (RIP_$FIND_NEXTHOP); one counter per routing table entry,
    from 0 (RIP_$NET_LOOKUP). }
  rip_$stats_t = record
    unused_00: integer;                   { 0x00 }
    packets_received: integer32;          { 0x02 }
    unused_06: integer;                   { 0x06 }
    errors: integer;                      { 0x08 }
    unknown_commands: integer;            { 0x0A }
    local_net_pkts: integer32;            { 0x0C }
    net_pkts: array[0..63] of integer32;  { 0x10 }
  end;

  { The record RIP_$TABLE_D reads a routing table entry's route into or
    writes it from, 0x1A bytes: when it expires,
    the network, the next hop (the route's record copied whole), the
    port's type and socket, the words ROUTE_$FIND_PORT takes, the socket
    widened by its sign and both copied from the port record
    (route/route.ins.pas's port_type and socket, integer); the hop count
    and the state, words whose low bytes go into the route's byte and
    bits unmasked: non-negative, pinteger. }
  rip_$table_d_buf_t = record
    expiration: integer32;                { 0x00 }
    dest_network: integer32;              { 0x04 }
    nexthop: rip_$nexthop_t;              { 0x08 }
    port_type: integer;                   { 0x12 }
    port_socket: integer;                 { 0x14 }
    metric: pinteger;                     { 0x16 }
    state: pinteger;                      { 0x18 }
  end;

  { The record RIP_$TABLE reads a route into or writes it from, 0x10
    bytes: the network; the next hop's node, a
    longword, masked when it is merged into the 20-bit field (a value of
    a type with negative values), integer32; when
    the route expires; the port's index and the hop count, bytes; the
    state in the top two bits of the byte at 0xE, set and read as a
    route's, rip_$route_state_t, whose word is the record's last. }
  rip_$table_buf_t = record
    dest_network: integer32;              { 0x00 }
    nexthop_host_low: integer32;          { 0x04 }
    expiration: integer32;                { 0x08 }
    port_index: rip_$byte_t;              { 0x0C }
    metric: rip_$byte_t;                  { 0x0D }
    flags: rip_$route_state_t;            { 0x0E }
  end;

  { An entry of a RIP packet, 6 bytes: the network
    and its hop count (RIP_$SERVER passes the word on as
    RIP_$UPDATE_INT's hop count). }
  rip_$pkt_entry_t = record
    network: integer32;                   { 0x00 }
    metric: integer;                      { 0x04 }
  end;

  { A RIP packet, 0x21E bytes: the command and up
    to 90 entries, which RIP's routines index from 1 (the request arm of
    rip_$process_request reads entry i's network at the packet plus 2 +
    6 * (i - 1)); RIP_$SERVER copies one whole and gives
    PKT_$BRK_INTERNET_HDR its size. }
  rip_$packet_t = record
    command: integer;                     { 0x00 }
    entries: array[1..rip_max_entries] of rip_$pkt_entry_t;  { 0x02 }
  end;
  rip_$packet_ptr_t = ^rip_$packet_t;

var
  { XNS_ERROR_$CLIENT_MUTEX (map symbol, +0x10 of the RIP_WIRED data
    block): the lock MAYBE_OPEN_ERROR_SOCKET and MAYBE_CLOSE_ERROR_SOCKET
    hold, pushed by its address (another unit's variable),
    ML_$EXCLUSION_START and _STOP's `var' (ml/ml.ins.pas): an
    ml_$exclusion_t.  RIP_$INIT initializes it. }
  xns_error_$client_mutex: extern ml_$exclusion_t;

type
  { The flags word of the packet info template, a word set: ROUTE's
    announcer takes member 7 out of its copy. }
  rip_$template_flags_t = set of 0..15;

  { The 30-byte packet info template RIP_$BCAST_CONTROL holds: copied
    whole into ROUTE's announcer's frame as seven longwords and a word,
    and passed as PKT_$SEND_INTERNET's packet info: pkt/pkt.ins.pas
    pkt_$info_t without its pad word, the names and offsets those of its
    first 30 bytes, the flags the set above.  msg/msg.ins.pas
    msg_$template_t is the same 30 bytes (see the TODO(pascal) in
    rem_name/send_request.pas for the 30 bytes against pkt_$info_t's
    32).  Its initial value is rip/rip_wired.pas's. }
  rip_$template_t = record
    flags: rip_$template_flags_t;         { 0x00 }
    routing_type: integer;                { 0x02 }
    addr_type: integer;                   { 0x04 }
    protocol: pinteger;                   { 0x06 }
    retry_limit: pinteger;                { 0x08 }
    field_0a: pinteger;                   { 0x0A }
    field_0c: pinteger;                   { 0x0C }
    addr: array[1..16] of char;           { 0x0E }
  end;

var
  { ROUTE_$SERVICE_MUTEX (map symbol, +0x28 of the RIP_WIRED data
    block): the lock ROUTE_$SERVICE holds, pushed by its address: an
    ml_$exclusion_t, ML_$EXCLUSION_START and _STOP's `var'
    (ml/ml.ins.pas).  RIP_$INIT initializes it. }
  route_$service_mutex: extern ml_$exclusion_t;

  { RIP_$STD_IDP_CHANNEL (map symbol, +0xC64 of RIP's block): the
    standard routing's IDP channel, 16#FFFF when there is none.
    ROUTE_$SERVICE compares it with 16#FFFF, and passes it by address to
    XNS_IDP_$OS_ADD_PORT and _DELETE_PORT's `in channel: pinteger'
    (xns/xns_idp.ins.pas): pinteger, as XNS_ERROR_$STD_IDP_CHANNEL and
    APP_$STD_IDP_CHANNEL. }
  rip_$std_idp_channel: extern pinteger;

  { RIP_$BCAST_CONTROL (map symbol, +0xC68 of RIP's block): the template
    above; ROUTE's announcer copies it. }
  rip_$bcast_control: extern rip_$template_t;

var
  { The map symbols of RIP's wired block, the RIP_WIRED data segment
    (rip/rip_wired.pas defines them; their offsets and initial values
    are listed there).

    RIP_$STATS (+0x54): the counters (rip_$stats_t above), reached
    through A5 by the wired routines and at their own addresses by the
    others. }
  rip_$stats: extern rip_$stats_t;

  { RIP_$INFO (+0x164): the routing table, 64 entries from 0
    (rip_$entry_t above), the displacement 0 for entry 0. }
  rip_$info: extern array[0..63] of rip_$entry_t;

  { RIP_$NS_ANNOUNCEMENT (+0xC66): the two bytes, the word 3
    (rip_cmd_name_register above), that RIP_$ANNOUNCE_NS sends as its
    packet's template with the length 2. }
  rip_$ns_announcement: extern integer;

  { RIP_$STD_RECENT_CHANGES (+0xC86) and RIP_$RECENT_CHANGES (+0xC88):
    whether a route of the standard routing, or of the Domain internet,
    changed since RIP last sent its table: set (RIP_$AGE), tested and
    cleared (RIP_$SEND_UPDATES): booleans. }
  rip_$std_recent_changes: extern boolean;
  rip_$recent_changes: extern boolean;

{ The routine headings, in map order (RIP_WIRED's WIRED_PROC and
  OS_INIT_PROC segments, RIP_UNWIRED's, RIP_RTWIRED's).  The bodies
  repeat the full headings (ref 7.3.4, Method 2).  RIP_$STD_DEMUX's
  heading is in rip/rip_xns.ins.pas. }

{ RIP_$NET_LOOKUP - the routing table entry of a network. }
function rip_$net_lookup(network: integer32; inc_refcount: boolean;
                         create: boolean): integer32;
  options(extern, val_param, a0_return);

{ RIP_$AGE - age the routing table's routes. }
procedure rip_$age; extern;

{ RIP_$FIND_NEXTHOP - the next hop and port towards a destination. }
function rip_$find_nexthop(in addr_info: univ rip_$dest_addr_t;
                           flags: boolean;
                           out port_ret: integer;
                           out nexthop: rip_$nexthop_t;
                           out status_ret: status_$t): integer;
  options(extern, val_param);

{ RIP_$PORT_CLOSE - expire the routes through a closing port. }
procedure rip_$port_close(port_index: integer; std: boolean; force: boolean);
  options(extern, val_param);

{ RIP_$UPDATE_INT - take a route to a network into the routing table. }
procedure rip_$update_int(network: integer32;
                          in source: univ rip_$nexthop_t;
                          hop_count: pinteger;
                          port_index: integer;
                          flags: boolean;
                          out status_ret: status_$t);
  options(extern, val_param);

{ RIP_$STD_OPEN - open the standard routing's IDP channel. }
procedure rip_$std_open; extern;

{ RIP_$INIT - set up RIP's locks and, on a diskless node, learn the node's
  network from its mother node. }
procedure rip_$init; extern;

{ RIP_$SEND_UPDATES - broadcast the routing table if a route changed. }
procedure rip_$send_updates(is_std: boolean); options(extern, val_param);

{ RIP_$SERVER - take one RIP packet off socket 8 and act on it. }
procedure rip_$server; extern;

{ RIP_$TABLE_D - read or write one route of a routing table entry. }
procedure rip_$table_d(in op_flag: boolean; in route_type: boolean;
                       in out index: integer;
                       var buffer: rip_$table_d_buf_t;
                       out status_ret: status_$t); extern;

{ RIP_$TABLE - read or write one standard-routing route of the table in
  the compact form. }
procedure rip_$table(in op_flag: boolean; var index: integer;
                     var buffer: rip_$table_buf_t); extern;

{ RIP_$UPDATE_D - take a route through a port named by its type and socket
  into the routing table. }
procedure rip_$update_d(in network: integer32;
                        in source: univ rip_$dest_addr_t;
                        in hop_count: integer;
                        in port_info: route_$short_port_t;
                        in flags: boolean;
                        out status_ret: status_$t);
  extern;

{ RIP_$UPDATE - take a route through a port named by its index into the
  routing table, as the Domain internet's. }
procedure rip_$update(in network: integer32; in host_id: linteger;
                      in hop_count: pinteger; in port_index: integer;
                      out status_ret: status_$t); extern;

{ RIP_$ANNOUNCE_NS - announce this node as a name server. }
procedure rip_$announce_ns; extern;

{ RIP_$SEND - send a RIP packet to one port or every port. }
procedure rip_$send(var addr_info: route_$xns_addr_t;
                    port_index: integer;
                    in route_data: univ rip_$packet_t;
                    route_len: integer;
                    flags: boolean);
  options(extern, val_param);

{ RIP_$BROADCAST - send the routing table of one routing to every port. }
procedure rip_$broadcast(flags: boolean); options(extern, val_param);

{ RIP_$HALT_ROUTER - tell every port that this node no longer routes. }
procedure rip_$halt_router(flags: boolean); options(extern, val_param);
