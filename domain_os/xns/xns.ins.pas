{ xns/xns.ins.pas - XNS_IDP_ (the XNS internet datagram protocol), for
  the Domain Pascal tree.

  The statuses and constants, the address types, the IDP header, the
  packet descriptor a channel's demux routine is given, the demux
  routine's type, the channel open record and the heading of
  XNS_IDP_$OS_OPEN: what needs only base, pkt and route, for APP and
  PKT.  The XNS modules' own types and the other headings are in
  xns/xns_idp.ins.pas.

  Include base/base.ins.pas, pkt/pkt.ins.pas and route/route.ins.pas
  before it.
}

const
  { The IDP header's length: the application header follows it
    (APP_$RECEIVE, APP_$DEMUX). }
  xns_idp_header_size = 30;

  { The XNS IDP statuses, module 0x3B (the texts stcode.db.10.2's), each
    with the routine that stores it: 16#3B0001 "no channels available",
    XNS_IDP_$OS_OPEN; 16#3B0002 "no OS sockets available", XNS_IDP_$OPEN;
    16#3B0004 "channel is not open", XNS_IDP_$CLOSE, _$SEND, _$RECEIVE;
    16#3B0005 "no socket allocated for caller", XNS_IDP_$RECEIVE; 16#3B0006
    "no packet available to receive", XNS_IDP_$RECEIVE; 16#3B0007 "data
    capacity too small for received packet", XNS_IDP_$RECEIVE; 16#3B0008
    "illegal buffer specification", XNS_IDP_$OS_SEND, _$SEND, _$RECEIVE;
    16#3B000B "listen network not connected", XNS_IDP_$OS_OPEN; 16#3B000C
    "illegal IDP socket", XNS_IDP_$OPEN; 16#3B000D "IDP socket table full",
    XNS_IDP_$OS_OPEN; 16#3B000E "IDP socket in use", XNS_IDP_$OS_OPEN,
    _$OPEN; 16#3B0010 "no client for packet", XNS_IDP_$OS_DEMUX,
    XNS_IDP_$DEMUX; 16#3B0011 "bad IDP checksum", XNS_IDP_$OS_DEMUX,
    _$OS_SEND; 16#3B0012 "maximum hops exceeded by packet",
    XNS_IDP_$OS_DEMUX; 16#3B0013 "network unreachable", XNS_IDP_$OS_OPEN,
    _$OS_SEND; 16#3B0015 "invalid version number", XNS_IDP_$OPEN; 16#3B0016
    "could not put packet into socket", XNS_IDP_$OS_DEMUX, XNS_IDP_$DEMUX;
    16#3B0017 "no OS socket depth given", XNS_IDP_$OPEN; 16#3B0018 "cannot
    send only as well as listen", XNS_IDP_$OPEN; 16#3B0019 "cannot send only
    as well as connect", XNS_IDP_$OPEN; 16#3B001A "cannot connect to
    broadcast address", XNS_IDP_$OPEN; 16#3B001B "connection source address
    must be this node", XNS_IDP_$OS_OPEN; 16#3B001C "cannot connect as well
    as listen", XNS_IDP_$OPEN; 16#3B001D "host address table full",
    XNS_IDP_$REGISTER_ADDR.  No routine stores 16#3B0003, 09, 0A, 0F or 14.
    }
  status_$xns_channel_table_full = 16#003B0001;
  status_$xns_no_os_sockets = 16#003B0002;
  status_$xns_bad_channel = 16#003B0004;
  status_$xns_no_socket = 16#003B0005;
  status_$xns_no_data = 16#003B0006;
  status_$xns_buffer_too_small = 16#003B0007;
  status_$xns_illegal_buffer_spec = 16#003B0008;
  status_$xns_listen_network_not_connected = 16#003B000B;
  status_$xns_reserved_socket = 16#003B000C;
  status_$xns_idp_socket_table_full = 16#003B000D;
  status_$xns_socket_in_use = 16#003B000E;
  status_$xns_no_client_for_packet = 16#003B0010;
  status_$xns_bad_checksum = 16#003B0011;
  status_$xns_hop_count_exceeded = 16#003B0012;
  status_$xns_network_unreachable = 16#003B0013;
  status_$xns_version_mismatch = 16#003B0015;
  status_$xns_could_not_put_packet_into_socket = 16#003B0016;
  status_$xns_no_buffer_size = 16#003B0017;
  status_$xns_incompatible_flags = 16#003B0018;
  status_$xns_incompatible_flags2 = 16#003B0019;
  status_$xns_connect_to_broadcast = 16#003B001A;
  status_$xns_source_must_be_this_node = 16#003B001B;
  status_$xns_connect_bind_conflict = 16#003B001C;
  status_$xns_too_many_addrs = 16#003B001D;

  { The XNS Error Protocol's statuses, module 0x39 (stcode.db.10.2: "source
    is broadcast address", "illegal buffer specification", "packet type
    error"): XNS_ERROR_$SEND stores them. }
  status_$xns_error_source_is_broadcast = 16#00390001;
  status_$xns_error_illegal_buffer_spec = 16#00390002;
  status_$xns_error_packet_type_error = 16#00390003;

  { The bounds of the XNS_IDP block's tables: the channel bound
    (XNS_IDP_$OS_OPEN, XNS_IDP_$CLOSE), the channel and port loops'
    counts, the address table's bound (XNS_IDP_$REGISTER_ADDR). }
  xns_max_channels = 16;
  xns_max_ports = 8;
  xns_max_addrs = 4;

  { The user socket word of a channel with none (XNS_IDP_$OS_OPEN,
    XNS_IDP_$RECEIVE, XNS_IDP_$OPEN). }
  xns_no_socket = 16#E1;

  { The first socket XNS_IDP_$OS_OPEN hands out again after the last
    (also XNS_IDP_$INIT's initial value). }
  xns_first_dynamic_port = 16#BB9;

  { The reserved sockets: XNS_IDP_$OPEN refuses 1, 3, 0x499 and 16#FFFF;
    MAYBE_OPEN_ERROR_SOCKET opens 3; XNS_ERROR_$SEND sends from it. }
  xns_socket_rip = 1;
  xns_socket_echo = 2;
  xns_socket_error = 3;
  xns_socket_router = 16#499;

  { The IDP packet type of the error protocol: XNS_ERROR_$SEND tests and
    stores it. }
  xns_idp_type_error = 3;

  { The error protocol's codes XNS_IDP_$OS_DEMUX reports, passed by
    address as its constant cells. }
  xns_error_bad_checksum = 1;
  xns_error_bad_checksum_transit = 16#201;
  xns_error_param_none = 0;

  { The MAC frame type of an IDP packet: XNS_IDP_$OS_SEND's, and
    xns_$add_port's range 0x600..0x600. }
  xns_mac_frame_type = 16#600;

  { The members of an open record's flag word (xns_$open_flags_t below;
    the masks 0x02, 0x04, 0x08 of members 1, 2 and 3), tested by
    XNS_IDP_$OPEN and XNS_IDP_$OS_OPEN.  The statuses XNS_IDP_$OPEN
    stores when two are set together name them: 1 listen, 2 connect, 3
    send only (16#3B0018, 19, 1C above). }
  xns_open_flag_bind_local = 1;
  xns_open_flag_connect = 2;
  xns_open_flag_no_alloc = 3;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  xns_$byte_t = [byte] 0..255;

  { An XNS address, 12 bytes: the network, the host's three words and
    the socket.  route/route.ins.pas's route_$xns_addr_t is this record
    (the routing port's own XNS address), so the two names are one type.
    The XNS routines copy it whole as three longwords (XNS_IDP_$OS_SEND,
    XNS_IDP_$OS_OPEN, XNS_ERROR_$SEND), and read the host by words
    (xns_$is_local_addr). }
  xns_$addr_t = route_$xns_addr_t;

  { The 24 bytes of a destination address and a source address, as the
    XNS routines copy them between records: one byte at a time
    (XNS_IDP_$OS_SEND, XNS_IDP_$OPEN, XNS_IDP_$SEND, XNS_IDP_$RECEIVE),
    the copy of a character array (dbuf/dbuf.ins.pas dbuf_$ident_t,
    rem_name/rem_name.ins.pas: a record of these sizes is copied by
    longwords).  So the records that hold the two
    addresses have this view as well. }
  xns_$addr_bytes_t = array[1..24] of char;

  { A buffer descriptor, 12 bytes: the length, the address and the next
    descriptor (mac_os/mac_os.ins.pas declares the same record as
    mac_os_$buf_desc_t).  The XNS routines walk chains of them
    (XNS_IDP_$OS_SEND), and copy the head of a chain into records as one
    12-byte record (XNS_IDP_$OS_DEMUX, XNS_IDP_$OS_SEND, XNS_IDP_$SEND).
    Declared here, not taken from mac_os.ins.pas, because the descriptor
    below needs it and this file's includers do not include mac_os's
    (above). }
  xns_$buf_desc_ptr_t = ^xns_$buf_desc_t;
  xns_$buf_desc_t = record
    length: integer32;                    { 0x00 }
    address: integer32;                   { 0x04 }
    next: xns_$buf_desc_ptr_t;            { 0x08 }
  end;

  { A packet's data part, 20 bytes: its length and its four data pages
    (pkt/pkt.ins.pas pkt_$data_pages_t, from 1).  The XNS routines copy
    it whole (XNS_IDP_$OS_DEMUX, XNS_IDP_$OS_SEND), and read the length
    and the pages (xns_$get_checksum). }
  xns_$data_desc_t = record
    length: integer32;                    { 0x00 }
    pages: pkt_$data_pages_t;             { 0x04 }
  end;

  { The IDP header, 30 bytes.  APP_$RECEIVE reads the two networks.  The
    longwords lie at 2 mod 4, which an unpacked record allows (ref
    3.10.5.5: objects longer than a byte are word aligned).  The 24 bytes
    from 6 are read three ways, a variant part (ref 3.10.3): as the
    fields APP names (arm 1); as the destination and the source address,
    copied whole (arm 2; xns_$addr_t above); and as one character array
    (arm 3, xns_$addr_bytes_t above).  transport_ctl and packet_type are
    bytes read as unsigned integers (XNS_IDP_$OS_DEMUX, XNS_ERROR_$SEND,
    XNS_IDP_$RECEIVE widen them with zeros): the form of a `[byte]
    0..255' field widened (sock/sock.ins.pas, the descriptor's queue
    count; a char is compared as a byte), so xns_$byte_t (APP reads
    neither).  checksum is compared with and set to 16#FFFF.  length is
    signed: xns_$get_checksum widens it by its sign before comparing it
    with a longword, so integer (APP does not read it). }
  xns_$idp_header_t = record
    checksum: pinteger;                   { 0x00 }
    length: integer;                      { 0x02 }
    transport_ctl: xns_$byte_t;           { 0x04 }
    packet_type: xns_$byte_t;             { 0x05 }
    case integer of
      1: (dest_network: integer32;        { 0x06 }
          dest_host: array[1..6] of char; { 0x0A }
          dest_socket: pinteger;          { 0x10 }
          src_network: integer32;         { 0x12 }
          src_host: array[1..6] of char;  { 0x16 }
          src_socket: pinteger);          { 0x1C }
      2: (dest: xns_$addr_t;              { 0x06 }
          src: xns_$addr_t);              { 0x12 }
      3: (addrs: xns_$addr_bytes_t);      { 0x06 }
  end;
  xns_$idp_header_ptr_t = ^xns_$idp_header_t;

  { The packet descriptor XNS_IDP_$OS_DEMUX builds and passes to a
    channel's demux routine, 0x48 bytes.  APP_$DEMUX reads header,
    mac_src_hi and mac_src_lo, the low word of data_len, port_info and
    the 16 bytes from +0x38.  The 20 bytes from +0x34 are read two ways:
    the variant part.  The arm's 16 bytes from +0x38 are
    pkt/pkt.ins.pas's pkt_$data_pages_t, the type of the field they are
    copied into.  Two more views, each a variant arm.  The 12 bytes from
    +0x18 (data_len, header, iov) are a buffer descriptor, head
    (xns_$buf_desc_t above): XNS_IDP_$OS_DEMUX copies the received
    packet's descriptor there whole, and XNS_ERROR_$SEND's routines walk
    the chain from it (xns_$pkt_bufs_in_netbuf_pool,
    xns_$setup_error_header).  The 20 bytes from +0x34 are a data part,
    data (xns_$data_desc_t above), copied whole; arm 1 reads its length
    (netbuf_len) and its first page (netbuf_handle).  pkt_len is
    unsigned: XNS_IDP_$DEMUX widens it with zeros (APP does not read it).
    channel is the address of the receiving channel's record
    (XNS_IDP_$OS_DEMUX stores it, XNS_IDP_$DEMUX reads through it), kept
    an integer32 (the channel's type is xns/xns_idp.ins.pas's). }
  xns_$pkt_desc_t = record
    unknown_00: array[1..24] of char;  { 0x00 }
    case integer of
      1: (data_len: integer32;            { 0x18 }
          header: integer32;              { 0x1C }
          iov: integer32;                 { 0x20 }
          from_net: boolean;              { 0x24 }
          unknown_25: char;               { 0x25 }
          mac_src_hi: integer32;          { 0x26 }
          mac_src_lo: integer;            { 0x2A }
          pkt_len: pinteger;              { 0x2C }
          unknown_2e: integer;            { 0x2E }
          channel: integer32;             { 0x30 }
          case integer of
            1: (netbuf_len: integer32;    { 0x34 }
                netbuf_handle: integer32; { 0x38 }
                netbuf_rest: array[1..12] of char);  { 0x3C }
            2: (unknown_34: integer;      { 0x34 }
                port_info: integer;       { 0x36 }
                mac_info: pkt_$data_pages_t);  { 0x38 }
            3: (data: xns_$data_desc_t)); { 0x34 }
      2: (head: xns_$buf_desc_t);         { 0x18 }
  end;

  { A pointer to a descriptor: XNS_ERROR_$SEND keeps its descriptor's
    address in a local, through which its nested routine reads the data
    part. }
  xns_$pkt_desc_ptr_t = ^xns_$pkt_desc_t;

  { A channel's demux routine: XNS_IDP_$OS_DEMUX calls it with five
    addresses: the default convention.  Its modes are APP_$DEMUX's
    (app/app.ins.pas), the one routine whose address is stored in such a
    field (APP_$STD_OPEN).  XNS_IDP_$OPEN stores
    XNS_IDP_$DEMUX's address in one too; its heading
    (xns/xns_idp.ins.pas) has these modes. }
  xns_$demux_proc_t = ^procedure(in pkt: xns_$pkt_desc_t;
                                 in port_type: integer;
                                 in port_socket: integer;
                                 in mac_broadcast: boolean;
                                 out status: status_$t);

  { The flag word of an open record, a word set, member k bit k, its members
    tested through the low byte (XNS_IDP_$OS_OPEN, XNS_IDP_$OPEN); the
    members are the constants xns_open_flag_ above.  XNS_IDP_$OPEN copies
    the user record's word into its XNS_IDP_$OS_OPEN record whole. }
  xns_$open_flags_t = set of 0..15;

  { The channel open record, 0x24 bytes.  APP_$STD_OPEN fills socket and
    flags_channel with one longword store, demux with a routine's
    address and network, and reads flags_channel back, the channel index
    XNS_IDP_$OS_OPEN leaves there.  The record from +0x02 is a variant
    part: the word at +0x02 is the flag set before the call
    (xns_$open_flags_t above; tested by members) and the channel index
    after it (flags_channel, a pinteger), so arm 2 holds the set.  The 24
    bytes from +0x0C are, like the IDP header's, two addresses copied
    whole (src and dest; XNS_IDP_$OS_OPEN) or as bytes (addrs:
    XNS_IDP_$OPEN fills them so): an inner variant part.  The existing
    fields are arm 1's, their names kept. }
  xns_$os_open_opt_t = record
    socket: integer;                      { 0x00 }
    case integer of
      1: (flags_channel: pinteger;        { 0x02 }
          demux: xns_$demux_proc_t;       { 0x04 }
          network: integer32;             { 0x08 }
          case integer of
            1: (src_network: integer32;   { 0x0C }
                src_host_hi: pinteger;    { 0x10 }
                src_host_mid: pinteger;   { 0x12 }
                src_host_lo: pinteger;    { 0x14 }
                src_socket: pinteger;     { 0x16 }
                dest_network: integer32;  { 0x18 }
                dest_host_hi: pinteger;   { 0x1C }
                dest_host_mid: pinteger;  { 0x1E }
                dest_host_lo: pinteger;   { 0x20 }
                dest_socket: pinteger);   { 0x22 }
            2: (src: xns_$addr_t;         { 0x0C }
                dest: xns_$addr_t);       { 0x18 }
            3: (addrs: xns_$addr_bytes_t));  { 0x0C }
      2: (flags: xns_$open_flags_t);      { 0x02 }
  end;

{ XNS_IDP_$OS_OPEN - open an IDP channel (the OS's call). }
procedure xns_idp_$os_open(in out opt: xns_$os_open_opt_t;
                           out status: status_$t); extern;
