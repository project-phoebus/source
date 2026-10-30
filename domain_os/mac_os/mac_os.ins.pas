{ mac_os/mac_os.ins.pas - MAC_OS (the MAC layer's OS side), for the Domain
  Pascal tree.

  The records MAC_ and MAC_OS_ routines share, the channel table's
  entry, and the headings of the MAC_OS_ routines MAC_ calls.  Its module
  file is mac_os/mac_os.pas, which holds the MAC_ fragments of mac/ too
  (mac_os/README.md).  Include base/base.ins.pas, ml/ml.ins.pas,
  pkt/pkt.ins.pas, rip/rip.ins.pas and route/route.ins.pas before it.
}

const
  { MAC_OS's status codes that MAC_ routines store.
    status_$mac_illegal_buffer_spec, "illegal buffer specification"
    (stcode.db.10.2), stored by MAC_$RECEIVE.  status_$mac_XXX_unknown,
    stored by MAC_$DEMUX and MAC_OS_$DEMUX: stcode.db.10.2 has no text for
    0x3A000F (it lists 0x3A000D and 0x3A0010), so the name is a placeholder.
    }
  status_$mac_illegal_buffer_spec = 16#003A000C;
  status_$mac_XXX_unknown = 16#003A000F;

  {

    The MAC_OS_ routines' other statuses (the texts stcode.db.10.2's):
    16#003A0001 "port operation not implemented" (MAC_OS_$OPEN, _$CLOSE,
    _$SEND, _$ARP), 16#003A0002 "no channels available", 16#003A0003 "packet
    type table full", 16#003A0005 "packet type in use" (MAC_OS_$OPEN),
    16#003A000D "invalid port version number" (MAC_OS_$PUT_INFO),
    16#003A0013 "illegal destination address" (MAC_OS_$ARP; the name says
    ARP found no address).  16#003A000E (MAC_OS_$PUT_INFO) has no text in
    stcode.db.10.2, so the name is a placeholder. }
  status_$mac_port_op_not_implemented = 16#003A0001;
  status_$mac_no_channels_available = 16#003A0002;
  status_$mac_packet_type_table_full = 16#003A0003;
  status_$mac_packet_type_in_use = 16#003A0005;
  status_$mac_invalid_port_version = 16#003A000D;
  status_$mac_XXX_unknown_2 = 16#003A000E;
  status_$mac_arp_address_not_found = 16#003A0013;

  { MAC_OS's bounds and sizes.  The channels
    (MAC_OS_$OPEN's bound, MAC_OS_$PROC2_CLEANUP's loop); a port's
    packet-type entries (MAC_OS_$OPEN); the header sizes by network type
    (MAC_OS_$OPEN's case); MAC_OS_$SEND's packet sizes and the split at
    16#400; the IP frame type in an Apollo XNS host's first word
    (MAC_OS_$ARP, MAC_OS_$INIT). }
  mac_os_max_channels = 10;
  mac_os_max_pkt_types = 20;
  mac_os_hdr_size_ethernet = 28;
  mac_os_hdr_size_token_ring = 14;
  mac_os_hdr_size_fddi = 0;
  mac_os_max_packet_size = 1976;
  mac_os_small_packet_size = 952;
  mac_os_large_packet_size = 1024;
  mac_os_ethertype_ip = 16#800;

  { The network types (route_$port_t.port_type) MAC_OS's cases test:
    MAC_OS_$OPEN's and MAC_OS_$ARP's jump tables have six entries, 1 and 2
    going to the `otherwise' part. }
  mac_os_net_type_ethernet = 0;
  mac_os_net_type_3 = 3;
  mac_os_net_type_token_ring = 4;
  mac_os_net_type_fddi = 5;

  { The socket word of a free channel: MAC_$CLOSE
    compares and stores it; MAC_$DEMUX and MAC_$RECEIVE compare with
    it. }
  mac_os_no_socket = 16#E1;

  { The channel flag word's set members:
    MAC_$CLOSE, MAC_$SEND and MAC_$RECEIVE load the word and test member
    9, MAC_$RECEIVE member 8 on the same register: a word set, member k
    bit k. }
  mac_os_channel_promiscuous = 8;
  mac_os_channel_in_use = 9;

type
  { A link-level address, 0x18 bytes: the number of address words, then
    the words.  The words are indexed from 0: MAC_$DEMUX and
    MAC_$RECEIVE step a pointer through them that starts at the record
    and reach each word at displacement 2: the field's offset with
    nothing folded for the lower bound, which a 1-based array would add
    (the stepped pointer `base + from * size' and
    the displacement `field - lo * size'; mac/demux.pas).  The record is
    route/route.ins.pas's route_$link_addr_t, the type of the routing
    port's own link address at 0x08, so the two names are one type. }
  mac_os_$link_addr_t = route_$link_addr_t;

  { A buffer descriptor, 12 bytes: MAC_$RECEIVE
    walks a chain of them and adds the length to a longword.  next is a
    pointer to the next one: MAC_$RECEIVE tests it against 0 and
    dereferences it.  MAC_$SEND copies the 12 bytes as one record. }
  mac_os_$buf_desc_ptr_t = ^mac_os_$buf_desc_t;
  mac_os_$buf_desc_t = record
    length: integer32;                    { 0x00 }
    address: integer32;                   { 0x04 }
    next: mac_os_$buf_desc_ptr_t;         { 0x08 }
  end;

  { A chain entry as MAC_$SEND reaches the entries after the first: a
    descriptor and a byte at 0x0C, which MAC_$SEND clears in every entry
    of the caller's chain.  In the packet record the first descriptor is
    followed by the same byte, hdr_prebuilt at 0x28 (below), so each
    entry is the descriptor and that flag. }
  mac_os_$buf_entry_ptr_t = ^mac_os_$buf_entry_t;
  mac_os_$buf_entry_t = record
    desc: mac_os_$buf_desc_t;             { 0x00 }
    flag_0c: boolean;                     { 0x0C }
  end;

  { A packet-type range, 8 bytes.  MAC_$OPEN
    compares the two unsigned, and copies each of the caller's ranges
    into its MAC_OS_$OPEN record as one 8-byte record: so the caller's
    ranges (mac/mac.ins.pas mac_$open_params_t) have this type too. }
  mac_os_$pkt_type_range_t = record
    range_low: linteger;                  { 0x00 }
    range_high: linteger;                 { 0x04 }
  end;

  { MAC_OS_$DEMUX's record of a received packet, 0x4C bytes.  MAC_$DEMUX
    reads the fields named here.  time is the arrival clock, a longword and
    a word at 0x2A, 0x2E: a time_$clock_t's first variant (word aligned).
    body_len and data_len are longwords of which MAC_$DEMUX takes the low
    words (0x1E, 0x3A: mac/demux.pas).  channel is the resolved channel's
    address, through which MAC_$DEMUX reads the channel's socket
    (MAC_OS_$DEMUX stores it). }
  mac_os_$channel_ptr_t = ^mac_os_$channel_t;
  mac_os_$rcv_pkt_t = record
    link_addr: mac_os_$link_addr_t;       { 0x00 }
    is_local: boolean;                    { 0x18 }
    unused_1a: integer;                   { 0x1A }
    body_len: integer32;                  { 0x1C }
    body: integer32;                      { 0x20 }
    unused_24: integer32;                 { 0x24 }
    unused_28: integer;                   { 0x28 }
    time: time_$clock_t;                  { 0x2A }
    frame_type: integer32;                { 0x30 }
    channel: mac_os_$channel_ptr_t;       { 0x34 }
    data_len: integer32;                  { 0x38 }
    data_pa: pkt_$data_pages_t;           { 0x3C }
  end;

  { MAC_OS_$SEND's packet record, 0x4C bytes (RING_$SEND_OS copies 0x13
    longwords).  MAC_$SEND builds one in its
    frame from the caller's: the link address as one record (a loop of
    six longwords); is_broadcast, frame_type, the data length and the
    first data page; hdr_desc as one 12-byte record; hdr_prebuilt a
    byte, cleared.  The bytes the image never names are unused_ fields
    (the kernel's records are laid out by the word rules, ref 3.10.5: a
    longword after a byte goes to the next word,
    so the image's offsets need them); the data pages are
    pkt_$data_pages_t (sock_$pkt_info_t's, pkt/pkt.ins.pas), the first
    cleared.  The data part, 20 bytes from 0x38, the length and the
    pages: XNS_IDP_$OS_SEND fills it as one record from its request
    record (a 20-byte record copy), so the two
    fields are also this record, a variant arm (the existing names
    kept). }
  mac_os_$data_desc_t = record
    length: integer32;                    { 0x00 }
    pages: pkt_$data_pages_t;             { 0x04 }
  end;

  mac_os_$send_pkt_t = record
    link_addr: mac_os_$link_addr_t;       { 0x00 }
    is_broadcast: boolean;                { 0x18 }
    unused_1a: integer;                   { 0x1A }
    hdr_desc: mac_os_$buf_desc_t;         { 0x1C }
    hdr_prebuilt: boolean;                { 0x28 }
    unused_2a: integer;                   { 0x2A }
    unused_2c: integer32;                 { 0x2C }
    frame_type: integer32;                { 0x30 }
    unused_34: integer32;                 { 0x34 }
    case integer of
      1: (data_length: integer32;         { 0x38 }
          data_pages: pkt_$data_pages_t); { 0x3C }
      2: (data: mac_os_$data_desc_t);     { 0x38 }
  end;

  { The receive callback a channel is opened with: MAC_OS_$DEMUX calls it
    through the channel's first longword with four addresses: its packet
    record, its own port and flag slots passed on, its status; the
    default convention.  MAC_$OPEN registers MAC_$DEMUX, whose heading
    (mac/mac.ins.pas) has these modes. }
  mac_os_$callback_t = ^procedure(in pkt: mac_os_$rcv_pkt_t;
                                  in port_num: integer;
                                  in demux_flag: boolean;
                                  out status: status_$t);

  { A channel's flag word, as a set (MAC_$CLOSE, _SEND, _RECEIVE: above,
    `mac_os_channel_in_use') and as packed fields (bits 10..15 the owner
    AS_ID).  The owner is read with the packed field form (MAC_$CLOSE,
    MAC_$SEND, MAC_$RECEIVE), the six top bits of the word, an unsigned
    field.  MAC_$OPEN stores the promiscuous bit as a boolean field from a
    boolean byte (bit 0 of the unit byte).  So the word is read two ways: a
    variant record (ref 3.10.3).  No MAC_ routine addresses low_byte. }
  mac_os_$channel_flags_t = set of 0..15;
  mac_os_$channel_bits_t = packed record
    owner: 0..63;                         { bits 15..10 }
    in_use: boolean;                      { bit 9 }
    promiscuous: boolean;                 { bit 8 }
    low_byte: 0..255;                     { bits 7..0 }
  end;

  { A channel, 20 bytes.  The table is a MAC_OS
    module variable at +0x7A0 of its block (mac/README.md).  MAC_
    routines reach an entry as A5 + 20 * channel and the fields at 0x7A0
    + offset: socket (0x7A8), the port (0x7AA), the flags (0x7B2).
    callback and driver_info are longwords (the callback tested and
    called by MAC_OS_$DEMUX). }
  mac_os_$channel_t = record
    callback: mac_os_$callback_t;         { 0x00 }
    driver_info: integer32;               { 0x04 }
    socket: pinteger;                     { 0x08 }
    port_index: integer;                  { 0x0A }
    callback_data: integer;               { 0x0C }
    line_number: integer;                 { 0x0E }
    header_size: integer;                 { 0x10 }
    case integer of
      1: (flags: mac_os_$channel_flags_t);  { 0x12 }
      2: (bits: mac_os_$channel_bits_t);    { 0x12 }
  end;

  { MAC_OS_$OPEN's parameter record, 0x56 bytes.
    The ranges at 0 are overwritten by the results: a variant record.
    MAC_$OPEN builds one in its frame (the callback, MAC_$DEMUX's
    address, at +0x50; num_pkt_types at +0x54; the ranges from 0) and
    reads the results (channel at +0x04, mtu at +0x00).  The ranges are
    indexed from 0 (the stepped pointer from the record: mac/open.pas). }
  mac_os_$open_params_t = record
    case integer of
      1: (pkt_types: array[0..9] of mac_os_$pkt_type_range_t;  { 0x00 }
          callback: mac_os_$callback_t;                        { 0x50 }
          num_pkt_types: integer);                             { 0x54 }
      2: (mtu: integer32;                                      { 0x00 }
          channel: pinteger);                                  { 0x04 }
  end;

  {

    A packet-type entry of a port's table, 12 bytes (the range is
    mac_os_$pkt_type_range_t): MAC_OS_$OPEN
    copies a caller's range into it as one 8-byte record and stores the
    channel after it; MAC_OS_$CLOSE and _$PROC2_CLEANUP move whole
    entries.  channel_index is a channel number (MAC_OS_$OPEN stores the
    unsigned channel, MAC_OS_$CLOSE compares it with its pinteger
    channel); reserved is never addressed.  The entries are indexed from
    0: mac_os_$find_packet_type's caller passes the array's address, the
    table's + 4, and the callee returns the index of the element at that
    address plus 12 times it, counting from 0. }
  mac_os_$pkt_type_entry_t = record
    range: mac_os_$pkt_type_range_t;      { 0x00 }
    channel_index: pinteger;              { 0x08 }
    reserved: integer;                    { 0x0A }
  end;
  mac_os_$pkt_type_array_t = array[0..19] of mac_os_$pkt_type_entry_t;

  { A port's packet-type table, 0xF4 bytes: the
    count, a word compared signed, and the entries at 4.  MAC_OS_$OPEN
    scales the port by the size, and MAC_OS_$INIT steps through the
    eight. }
  mac_os_$port_pkt_table_t = record
    entry_count: integer;                 { 0x00 }
    reserved: integer;                    { 0x02 }
    entries: mac_os_$pkt_type_array_t;    { 0x04 }
  end;

  { A port's record, 8 bytes: MAC_OS_$PUT_INFO
    compares the version as a longword, and copies the 8 bytes;
    MAC_OS_$INIT stores the version 1, the config word 0 and the
    driver's mtu word (the driver's field is a pinteger,
    net_io/net_io.ins.pas). }
  mac_os_$port_info_t = record
    version: integer32;                   { 0x00 }
    config: integer;                      { 0x04 }
    mtu: pinteger;                        { 0x06 }
  end;
  mac_os_$port_info_ptr_t = ^mac_os_$port_info_t;

  { The driver record's three MAC_OS entries (net_io/net_io.ins.pas
    net_io_$driver_t's open_os, close_os and send_os at 0x3C, 0x40, 0x44,
    univ_ptr there), from the calls:
    - open (MAC_OS_$OPEN): the routing port's socket word by value,
      MAC_OS_$OPEN's own record and status slots passed on;
    - close (MAC_OS_$CLOSE, and MAC_OS_$PROC2_CLEANUP with its own
      status): the channel's line number by value, its callback_data
      word and the status by address;
    - send (MAC_OS_$SEND): the line by value, the callback_data word,
      the packet record and MAC_OS_$SEND's bytes_sent and status slots
      by address.
    A word by value needs `val_param' (ref 5.2, Table 5-1); the word
    below the arguments is the alignment pad, not
    a result's place, so the entries are procedures.  The drivers'
    bodies (RING_, ETH_ ...) are not translated; the modes of the
    by-address arguments are `var' (what the drivers do with them is not
    seen here), the statuses `out'. }
  mac_os_$drv_open_t = ^procedure(line: integer;
                                  var params: mac_os_$open_params_t;
                                  out status: status_$t);
                       options(val_param);
  mac_os_$drv_close_t = ^procedure(line: integer;
                                   var callback_data: integer;
                                   out status: status_$t);
                        options(val_param);
  mac_os_$drv_send_t = ^procedure(line: integer;
                                  var callback_data: integer;
                                  var pkt: mac_os_$send_pkt_t;
                                  out bytes_sent: integer;
                                  out status: status_$t);
                       options(val_param);

var
  { MAC_OS_$PORTP_TABLE and MAC_OS_$PORT_TABLE (map symbols in MAC_OS's
    block, +0x87C and +0x89C; mac_os/mac_os.pas defines them): one
    pointer per port to its record, and the records.  MAC_OS_$INIT
    stores each pointer and fills each record; the ports count from 0
    (MAC_OS_$PUT_INFO reaches the record unscaled by a lower bound). }
  mac_os_$portp_table: extern array[0..7] of mac_os_$port_info_ptr_t;
  mac_os_$port_table: extern array[0..7] of mac_os_$port_info_t;

{ MAC_OS_$OPEN - open a channel on a port at the MAC_OS level. }
procedure mac_os_$open(in port_num: integer;
                       in out params: mac_os_$open_params_t;
                       out status: status_$t); extern;

{ MAC_OS_$CLOSE - close a channel at the MAC_OS level. }
procedure mac_os_$close(in channel: pinteger; out status: status_$t);
  extern;

{ MAC_OS_$SEND - send a packet on a channel at the MAC_OS level. }
procedure mac_os_$send(in channel: pinteger;
                       in out pkt: mac_os_$send_pkt_t;
                       out bytes_sent: integer;
                       out status: status_$t); extern;

{ MAC_OS_$DEMUX - hand a received packet to the channel its type belongs
  to. }
procedure mac_os_$demux(in out pkt: mac_os_$rcv_pkt_t;
                        in port_num: integer;
                        in demux_flag: boolean;
                        out status: status_$t); extern;

{ MAC_OS_$PROC2_CLEANUP - close the channels an ending process owns. }
procedure mac_os_$proc2_cleanup(as_id: integer);
  options(extern, val_param);

{ MAC_OS_$ARP - the link-level address for a next hop on a port. }
procedure mac_os_$arp(in nexthop: rip_$nexthop_t; port_num: integer;
                      out link_addr: mac_os_$link_addr_t;
                      out is_broadcast: boolean;
                      out status: status_$t);
  options(extern, val_param);

{ MAC_OS_$PUT_INFO - store a port's version and configuration record. }
procedure mac_os_$put_info(in info: mac_os_$port_info_t;
                           in port_num: integer;
                           out status: status_$t); extern;

{ MAC_OS_$INIT - set up MAC_OS's tables at boot. }
procedure mac_os_$init; extern;
