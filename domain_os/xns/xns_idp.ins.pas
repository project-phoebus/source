{ xns/xns_idp.ins.pas - the XNS modules' own types, variables and
  headings (XNS_IDP and XNS_ERROR), for the Domain Pascal tree.

  The MAC packet record as XNS reads it, the port and channel records
  of the XNS_IDP block, the IDP calls' request records, the error
  packet, the map's XNS variables and the XNS routines' headings
  (XNS_IDP_$OS_OPEN's is xns/xns.ins.pas's).

  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas,
  pkt/pkt.ins.pas, route/route.ins.pas, rip/rip.ins.pas,
  mac_os/mac_os.ins.pas and xns/xns.ins.pas before it.
}

const
  { The members of a channel's flag set (xns_$chan_flags_t below; the
    masks 0x0800, 0x1000, 0x2000, 0x4000, bits 11..14): the open record's
    flag members 0..4 land in members 11..15 (XNS_IDP_$OS_OPEN's merge,
    xns/idp_os_open.pas).  XNS_IDP_$OS_SEND tests 13 and 11;
    XNS_IDP_$RECEIVE 15 and 11.  Member 15 has no name. }
  xns_chan_flag_build_header = 11;
  xns_chan_flag_bind_local = 12;
  xns_chan_flag_connect = 13;
  xns_chan_flag_no_alloc = 14;

  { The member of a channel's state set that marks it open (bit 15): set
    and cleared through its byte (XNS_IDP_$OS_OPEN), tested as the word's
    sign (xns_$find_socket). }
  xns_chan_state_active = 15;

type
  { A host's three words (the registered addresses' three words each;
    every access a word move, XNS_IDP_$REGISTER_ADDR), from 0 as
    xns_$addr_t's host (route/route.ins.pas). }
  xns_$host_t = array[0..2] of pinteger;

  { MAC's packet record as the XNS routines read it, 0x4C bytes: the
    record a driver builds and MAC_OS_$DEMUX passes on to
    XNS_IDP_$OS_DEMUX (mac_os/mac_os.ins.pas mac_os_$rcv_pkt_t, the same
    record as mac_os_$send_pkt_t), given to xns_$get_checksum with the
    record XNS_IDP_$OS_SEND builds for MAC_OS_$SEND.  XNS_IDP_$OS_DEMUX
    copies two parts of it whole into the descriptor it builds
    (xns/xns.ins.pas xns_$pkt_desc_t's head and data): the buffer
    descriptor at 0x1C and the data part at 0x38: record copies, so the
    two parts are records of the descriptor's own types, a view MAC_OS's
    rcv_pkt_t does not have; and the descriptor's types are XNS's
    (xns/xns.ins.pas: its includers have no mac_os insert).  So XNS's own
    record.  The other fields XNS reads: the 6 bytes at 0x2A as a
    longword and a word (MAC_OS_$DEMUX's arrival time, mac_src_hi and
    mac_src_lo), the frame type, the descriptor's low length word, the
    data part's and pages.  The names are mac_os/mac_os.ins.pas's
    rcv_pkt_t's (hdr_desc for its body_len, body and unused_24). }
  xns_$mac_pkt_t = record
    link_addr: route_$link_addr_t;        { 0x00 }
    is_local: boolean;                    { 0x18 }
    unused_1a: integer;                   { 0x1A }
    hdr_desc: xns_$buf_desc_t;            { 0x1C }
    unused_28: integer;                   { 0x28 }
    mac_src_hi: integer32;                { 0x2A }
    mac_src_lo: integer;                  { 0x2E }
    frame_type: integer32;                { 0x30 }
    channel: integer32;                   { 0x34 }
    data: xns_$data_desc_t;               { 0x38 }
  end;

  { A routing port's state, 12 bytes, the elements of
    XNS_IDP_$PORT_TABLE.  xns_$add_port stores the two results of
    MAC_OS_$OPEN (mac_os_$open_params_t's channel and mtu; mac_handle
    named for the latter), and counts the channels using the port;
    xns_$delete_port closes the MAC channel, passing mac_socket as
    MAC_OS_$CLOSE's pinteger.  XNS_IDP_$INIT stores the routing port's
    pointer from ROUTE_$PORTP, and the two words with one longword store
    (adjacent stores merged); xns_$is_broadcast_addr and
    XNS_IDP_$OS_OPEN read the port's network through it: a
    route_$port_ptr_t. }
  xns_$port_state_t = record
    mac_handle: integer32;                { 0x00 }
    net_addr_ptr: route_$port_ptr_t;      { 0x04 }
    mac_socket: pinteger;                 { 0x08 }
    refcount: integer;                    { 0x0A }
  end;

  { A channel's flag word, read and written two ways, so a variant of a
    packed record (ref 3.10.3, 3.10.7; sock/sock.ins.pas sock_$flags_t
    the model).  XNS_IDP_$OS_OPEN merges
    the open record's flag byte into the five top bits as one field
    (on the unit byte, the value's high bits shifted out), and the owner's
    address space into bits 10..5 (PROC1_$AS_ID's low byte, as
    MAC_OS_$OPEN's `bits.owner := proc1_$as_id', mac_os/open.pas);
    XNS_IDP_$CLOSE reads the owner.  The tests are of members (const above).
    XNS_IDP_$OS_CLOSE and XNS_IDP_$INIT clear the open flags: the field :=
    0.  The names: open_flags and owner for the flags and the owning address
    space. }
  xns_$chan_flag_set_t = set of 0..15;
  xns_$chan_flags_t = packed record
    case integer of
      1: (open_flags: 0..31;              { bits 15..11 }
          owner: 0..63;                   { bits 10..5 }
          unused_low: 0..31);             { bits 4..0 }
      2: (members: xns_$chan_flag_set_t);
  end;

  { A channel's state word, a set (const above). }
  xns_$chan_state_t = set of 0..15;

  { A channel, 0x48 bytes, the elements of the XNS_IDP block's table at
    +0xA0 (the stride 0x48, times 72 in word arithmetic).  demux is the
    channel's demux routine, tested and called and copied from the open
    record: xns/xns.ins.pas xns_$demux_proc_t.  dest and src are XNS
    addresses copied whole (xns/xns.ins.pas xns_$addr_t; two records).
    mac_info is the next hop's link address, MAC_OS_$ARP's `out', copied
    into the MAC record whole: mac_os_$link_addr_t
    (route/route.ins.pas route_$link_addr_t).  connected_port is a port,
    -1 at boot.  user_socket a socket (compared with 16#E1, passed to
    SOCK_$GET, _$CLOSE, _$PUT's pinteger), xns_socket the channel's IDP
    socket, compared by words with the header's pinteger socket:
    pinteger.  port_active a boolean per port, from 0.  unused_46 is the
    stride's last word. }
  xns_$channel_t = record
    demux: xns_$demux_proc_t;             { 0x00 }
    dest: xns_$addr_t;                    { 0x04 }
    src: xns_$addr_t;                     { 0x10 }
    mac_info: mac_os_$link_addr_t;        { 0x1C }
    connected_port: integer;              { 0x34 }
    user_socket: pinteger;                { 0x36 }
    xns_socket: pinteger;                 { 0x38 }
    flags: xns_$chan_flags_t;             { 0x3A }
    port_active: array[0..7] of boolean;  { 0x3C }
    state: xns_$chan_state_t;             { 0x44 }
    unused_46: integer;                   { 0x46 }
  end;
  xns_$channel_ptr_t = ^xns_$channel_t;

  { The request record XNS_IDP_$OS_SEND is given, 0x48 bytes.  The two
    addresses at 0 are copied into the header by bytes (arm 2,
    xns/xns.ins.pas xns_$addr_bytes_t); XNS_IDP_$SEND fills them the same
    way.  hdr_desc is the head of the packet's buffer chain, read field
    by field and copied whole into the MAC record; hdr_prebuilt the byte
    after it (XNS_ERROR_$SEND sets it); both of MAC's send record's types
    (mac_os/mac_os.ins.pas mac_os_$send_pkt_t), which the copies need;
    packet_type a word whose low byte is the IDP type; data the payload's
    length and pages, its length's low word added to the IDP length and
    the part copied whole into MAC's record (mac_os/mac_os.ins.pas
    mac_os_$data_desc_t, the arm added for this copy). }
  xns_$os_send_rec_t = record
    case integer of
      1: (dest: xns_$addr_t;              { 0x00 }
          src: xns_$addr_t;               { 0x0C }
          hdr_desc: mac_os_$buf_desc_t;   { 0x18 }
          hdr_prebuilt: boolean;          { 0x24 }
          unused_26: integer;             { 0x26 }
          unused_28: integer32;           { 0x28 }
          packet_type: integer;           { 0x2C }
          unused_2e: integer;             { 0x2E }
          unused_30: integer32;           { 0x30 }
          data: mac_os_$data_desc_t);     { 0x34 }
      2: (addrs: xns_$addr_bytes_t);      { 0x00 }
  end;

  { The request record XNS_IDP_$SEND is given (its size 0x48 assumed;
    nothing reads past 0x2D): the two addresses copied by bytes, the
    chain's head tested and copied (mac_os_$buf_desc_t, the request
    record's type) and walked (the entries after the head as
    mac_os/mac_os.ins.pas mac_os_$buf_entry_t), the packet type's word. }
  xns_$idp_send_t = record
    case integer of
      1: (dest: xns_$addr_t;              { 0x00 }
          src: xns_$addr_t;               { 0x0C }
          hdr_desc: mac_os_$buf_desc_t;   { 0x18 }
          unknown_24: array[16#24..16#2B] of char;  { 0x24 }
          packet_type: integer;           { 0x2C }
          unknown_2e: array[16#2E..16#47] of char);  { 0x2E }
      2: (addrs: xns_$addr_bytes_t);      { 0x00 }
  end;

  { The record XNS_IDP_$RECEIVE is given, 0x48 bytes (the size assumed):
    the two addresses written by bytes from the header, the caller's
    buffer chain from 0x18, the MAC source (SOCK_$GET's src_addr and
    src_port), the packet type. }
  xns_$idp_recv_t = record
    case integer of
      1: (dest: xns_$addr_t;              { 0x00 }
          src: xns_$addr_t;               { 0x0C }
          iov: mac_os_$buf_desc_t;        { 0x18 }
          unknown_24: integer;            { 0x24 }
          mac_src_hi: integer32;          { 0x26 }
          mac_src_lo: integer;            { 0x2A }
          packet_type: integer;           { 0x2C }
          unknown_2e: array[16#2E..16#47] of char);  { 0x2E }
      2: (addrs: xns_$addr_bytes_t);      { 0x00 }
  end;

  { The record XNS_IDP_$OPEN is given, 0x24 bytes: the version, compared
    with 1; the socket; the network, copied as a longword into the
    XNS_IDP_$OS_OPEN record and overwritten on the way out with
    EC2_$REGISTER_EC1's result: a variant arm of an ec2_$ptr_t
    (ec/ec.ins.pas); the source and destination addresses from 0x08,
    0x14, their host words tested and the 24 bytes copied by bytes, the
    first word overwritten with the channel (channel_ret): inner arms;
    the flag set at 0x20 (xns/xns.ins.pas xns_$open_flags_t, tested
    through its low byte); the socket depth, tested. }
  xns_$idp_open_opt_t = record
    version: integer;                     { 0x00 }
    socket: integer;                      { 0x02 }
    case integer of
      1: (network: integer32;             { 0x04 }
          case integer of
            1: (src: xns_$addr_t;         { 0x08 }
                dest: xns_$addr_t;        { 0x14 }
                flags: xns_$open_flags_t; { 0x20 }
                buffer_size: integer);    { 0x22 }
            2: (addrs: xns_$addr_bytes_t);  { 0x08 }
            3: (channel_ret: pinteger));  { 0x08 }
      2: (ec: ec2_$ptr_t);                { 0x04 }
  end;

  { The IDP counters XNS_IDP_$GET_STATS returns, 12 bytes: three
    longwords. }
  xns_$idp_stats_t = record
    packets_sent: integer32;              { 0x00 }
    packets_received: integer32;          { 0x04 }
    packets_dropped: integer32;           { 0x08 }
  end;

  { The packet XNS_ERROR_$SEND builds in a network header buffer, 0x4C
    bytes: its own IDP header, the code and the parameter, and from 0x22
    the first 0x2A bytes of the offending packet
    (xns_$setup_error_header copies them there), whose IDP header's
    source address becomes the new destination: the offending header as
    a variant arm. }
  xns_$error_pkt_t = record
    idp: xns_$idp_header_t;               { 0x00 }
    error_code: integer;                  { 0x1E }
    error_param: integer;                 { 0x20 }
    case integer of
      1: (orig: array[1..42] of char); { 0x22 }
      2: (orig_hdr: xns_$idp_header_t);   { 0x22 }
  end;
  xns_$error_pkt_ptr_t = ^xns_$error_pkt_t;

var
  { XNS_IDP_$PORT_TABLE (map symbol, +0x40 of the XNS_IDP data segment;
    xns/xns_idp.pas defines it): the eight ports' state, from 0 (the port
    times 12); ROUTE_$PROCESS passes an element's mac_socket from the
    symbol. }
  xns_idp_$port_table: extern array[0..7] of xns_$port_state_t;

  { CLIENT_REF_COUNT and XNS_ERROR_$STD_IDP_CHANNEL (map symbols, +0x74
    and +0x76 of the XNS_ERROR data segment; xns/xns_error.pas defines
    them; CLIENT_REF_COUNT without `$', a global all the same).  The count
    of the error channel's users, tested, incremented, decremented: integer
    (no ordered compare).  The error channel, set from XNS_IDP_$OS_OPEN's
    channel word, passed by address to XNS_IDP_$OS_CLOSE and _$OS_SEND, set
    to -1 (the image's initial value): pinteger, those formals' type (and
    APP_$STD_IDP_CHANNEL's, app/app.ins.pas). }
  client_ref_count: extern integer;
  xns_error_$std_idp_channel: extern pinteger;

{ MAYBE_OPEN_ERROR_SOCKET - open the error protocol's IDP channel for
  one more user. }
procedure maybe_open_error_socket(out status: status_$t); extern;

{ MAYBE_CLOSE_ERROR_SOCKET - give up one user of the error protocol's
  IDP channel. }
procedure maybe_close_error_socket; extern;

{ XNS_ERROR_$SEND - answer an undeliverable packet with an XNS error
  packet. }
procedure xns_error_$send(in pkt: xns_$pkt_desc_t; in code: integer;
                          in param: integer; out result_ret: integer;
                          out status: status_$t); extern;

{ XNS_IDP_$OS_CLOSE - close an IDP channel (the OS's call). }
procedure xns_idp_$os_close(in channel: pinteger; out status: status_$t);
  extern;

{ XNS_IDP_$OS_SEND - send an IDP packet on a channel (the OS's call). }
procedure xns_idp_$os_send(in channel: pinteger;
                           in rec: xns_$os_send_rec_t;
                           out len_sent: integer;
                           out status: status_$t); extern;

{ XNS_IDP_$OS_DEMUX - deliver or forward a received IDP packet. }
procedure xns_idp_$os_demux(in pkt: xns_$mac_pkt_t; in port: integer;
                            in mac_broadcast: boolean;
                            out status: status_$t); extern;

{ XNS_IDP_$OS_ADD_PORT - bind a channel to a routing port, under the
  module's lock (the OS's call).
  XNS_IDP_$OS_DELETE_PORT - unbind a channel from a routing port, under
  the module's lock (the OS's call). }
procedure xns_idp_$os_add_port(in channel: pinteger; in port: integer;
                               out status: status_$t); extern;
procedure xns_idp_$os_delete_port(in channel: pinteger; in port: integer;
                                  out status: status_$t); extern;

{ XNS_IDP_$OPEN - open an IDP channel (the user's call). }
procedure xns_idp_$open(in out opt: xns_$idp_open_opt_t;
                        out status: status_$t); extern;

{ XNS_IDP_$CLOSE - close an IDP channel (the user's call). }
procedure xns_idp_$close(in channel: pinteger; out status: status_$t);
  extern;

{ XNS_IDP_$SEND - send an IDP packet on a channel (the user's call). }
procedure xns_idp_$send(in channel: pinteger; in rec: xns_$idp_send_t;
                        out len_sent: integer; out status: status_$t);
  extern;

{ XNS_IDP_$DEMUX - queue a received IDP packet on a user channel's
  socket. }
procedure xns_idp_$demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                         in port_socket: integer;
                         in mac_broadcast: boolean;
                         out status: status_$t); extern;

{ XNS_IDP_$RECEIVE - take the next packet of a channel's user socket
  into the caller's buffers. }
procedure xns_idp_$receive(in channel: pinteger;
                           in out rec: xns_$idp_recv_t;
                           out status: status_$t); extern;

{ XNS_IDP_$PROC2_CLEANUP - close the IDP channels of an ending address
  space. }
procedure xns_idp_$proc2_cleanup(as_id: integer);
  options(extern, val_param);

{ XNS_IDP_$GET_PORT_INFO - a port's information (not implemented). }
procedure xns_idp_$get_port_info(in channel: pinteger;
                                 var port_info: univ integer32;
                                 out status: status_$t); extern;

{ XNS_IDP_$GET_STATS - the IDP counters. }
procedure xns_idp_$get_stats(out stats: xns_$idp_stats_t;
                             out status: status_$t); extern;

{ XNS_IDP_$REGISTER_ADDR - register a host address of this node for a
  routing port. }
procedure xns_idp_$register_addr(in addr: xns_$host_t; in port: integer;
                                 out status: status_$t); extern;

{ XNS_IDP_$INIT - initialize the XNS_IDP block at boot. }
procedure xns_idp_$init; extern;

{ (XNS_IDP_ASM, hand assembly, xns/m68k/idp_checksum.s.)

  XNS_IDP_$CHECKSUM: the address and the word count read off the stack,
  the sum in D0's word.  Its caller (xns_$get_checksum) pushes a word
  after the pad and a longword: both by value, `val_param'; the address
  an integer32, the values the caller has (descriptors' addresses).
  XNS_IDP_$HOP_AND_SUM: two words off the stack; ROUTE_$PROCESS calls
  it. }
function xns_idp_$checksum(data: integer32; word_count: integer): integer;
  options(extern, val_param);
function xns_idp_$hop_and_sum(current_sum: integer; hop_offset: integer):
  integer; options(extern, val_param);
