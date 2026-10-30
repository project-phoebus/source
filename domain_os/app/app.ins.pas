{ app/app.ins.pas - APP (the application protocol layer) types,
  variables and routine headings, for the Domain Pascal tree.

  Only what the Pascal files use: the reply header, the received Domain
  packet header, the result record APP_$RECEIVE fills, the map-global
  APP_$STD_IDP_CHANNEL and the three headings.  The module is
  app/app.pas.  No customer insert file declares these.  Include
  base/base.ins.pas, ml/ml.ins.pas, pkt/pkt.ins.pas, sock/sock.ins.pas
  and xns/xns.ins.pas before it.
}

const
  { status_$network_buffer_queue_is_empty, 16#00110006, "buffer queue is
    empty" (OS / network, stcode.db.10.2): APP_$RECEIVE stores it when
    SOCK_$GET finds nothing. }
  status_$network_buffer_queue_is_empty = 16#00110006;

  { The reply's magic word, stored by APP_$RECEIVE. }
  app_reply_magic = 16#118;

  { The application header's socket number APP_$DEMUX retries on the
    overflow socket, and that socket. }
  app_sock_type_file = 2;
  app_sock_type_overflow = 6;

  { The longest reply that fits after the header in the buffer,
    APP_$RECEIVE's unsigned compare. }
  app_max_inline_size = 952;

  { The application protocol's socket and the open flags,
    APP_$STD_OPEN's one longword store. }
  app_std_protocol = 16#499;
  app_open_flag_bind_local = 2;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  app_$byte_t = [byte] 0..255;

  { The application header, 0x18 bytes, whose first eight bytes are the
    reply header (magic, template_len, data_len, request_id).
    APP_$RECEIVE builds it, APP_$DEMUX reads the received one.  The
    fields carry the prefix p_ (as netlog/netlog.ins.pas's e_):
    APP_$RECEIVE writes them inside a `with' over this record and the
    received header, where unprefixed names would hide its local
    net_type.  p_net_type is a boolean: APP_$DEMUX tests its sign
    (booleans), and APP_$RECEIVE copies a byte into it. }
  app_$pkt_hdr_t = record
    p_magic: integer;                     { 0x00 }
    p_template_len: integer;              { 0x02 }
    p_data_len: integer;                  { 0x04 }
    p_request_id: integer;                { 0x06 }
    p_src_node: integer32;                { 0x08 }
    p_src_sock: integer;                  { 0x0C }
    p_dest_node: integer32;               { 0x0E }
    p_dest_sock: integer;                 { 0x12 }
    p_net_type: boolean;                  { 0x14 }
    p_addr_size: app_$byte_t;             { 0x15 }
    p_flags: app_$byte_t;                 { 0x16 }
    p_reserved: char;                     { 0x17 }
  end;
  app_$pkt_hdr_ptr_t = ^app_$pkt_hdr_t;

  { The received Domain internet packet header, as APP_$RECEIVE reads it.
    rh_var holds the variable part's words, indexed by rh_sock_index
    from 0.  The variable part is read two ways, as words from 0x1E and
    as the fields from 0x20 on, so it is a variant part; the bound 255
    is the byte index's.  rh_flags_07 is a byte set, its member 3
    tested.  rh_proto_0e is copied into p_net_type, a boolean.
    rh_flags_07 is a `[byte] set of 0..7' field of the unpacked record
    (ref 3.15.5, p. 3-61: "a size attribute can specify a number of bits
    greater than the minimum for integer, boolean, and set data types"; a
    set of 0..7 needs 8 bits).  As a one-byte object it may sit at the
    odd offset 0x07 after the 7-char array (ref 3.10.5.5, p. 3-26: only
    objects longer than a byte are word aligned); a plain `set of 0..7'
    takes a word, word aligned (ref 3.9.3), and could not.  dpc supports
    the size attribute on a set. }
  app_$rcv_hdr_t = record
    unused_00: array[0..6] of char;       { 0x00 }
    rh_flags_07: [byte] set of 0..7;      { 0x07 }
    rh_node_08: integer32;                { 0x08 }
    rh_net_type: app_$byte_t;             { 0x0C }
    unused_0d: char;                      { 0x0D }
    rh_proto_0e: boolean;                 { 0x0E }
    unused_0f: char;                      { 0x0F }
    unused_10: integer;                   { 0x10 }
    rh_template_len: integer;             { 0x12 }
    unused_14: integer;                   { 0x14 }
    rh_request_id: integer;               { 0x16 }
    rh_hdr_size: app_$byte_t;             { 0x18 }
    rh_sock_index: app_$byte_t;           { 0x19 }
    rh_sock_1a: integer;                  { 0x1A }
    unused_1c: integer;                   { 0x1C }
    case integer of
      1: (rh_var: array[0..255] of integer);        { 0x1E }
      2: (unused_1e: integer;                       { 0x1E }
          rh_node_20: integer32;                    { 0x20 }
          unused_24: array[16#24..16#2C] of char;   { 0x24 }
          rh_addr_size: app_$byte_t;                { 0x2D }
          rh_net_2e: integer32;                     { 0x2E }
          unused_32: integer;                       { 0x32 }
          rh_node_34: integer32;                    { 0x34 }
          rh_sock_38: integer;                      { 0x38 }
          rh_net_3a: integer32;                     { 0x3A }
          unused_3e: integer;                       { 0x3E }
          rh_node_40: integer32;                    { 0x40 }
          rh_sock_44: integer;                      { 0x44 }
          unused_46: array[16#46..16#4A] of char;   { 0x46 }
          rh_subtype_4b: app_$byte_t);              { 0x4B }
  end;
  app_$rcv_hdr_ptr_t = ^app_$rcv_hdr_t;

  { The result record APP_$RECEIVE fills, 0x2C bytes.  reply and data
    are addresses used in arithmetic: integer32, converted to a pointer
    where reply is dereferenced.  The longword at +0x26 holds packed
    fields (an unaligned flags longword), so the record is packed (ref
    3.10.7): the boolean hdr_flag at bit 8 from +0x26, the top bit of
    byte 0x27, queue_count in bits 9..16 through the longword at +0x26,
    net_type in bits 17..24 through the word at +0x28.  The fields
    before are whole objects at even addresses, read and written as
    unpacked ones. }
  app_$receive_rec_t = packed record
    reply: integer32;                     { 0x00 }
    data: integer32;                      { 0x04 }
    data_pages: pkt_$data_pages_t;        { 0x08 }
    hdr_f06: integer32;                   { 0x18 }
    hdr_f12: integer32;                   { 0x1C }
    src_addr: integer32;                  { 0x20 }
    src_port: integer;                    { 0x24 }
    unused_26: 0..255;                    { 0x26, bits 0..7 }
    hdr_flag: boolean;                    { bit 8 (0x27 bit 7) }
    queue_count: 0..255;                  { bits 9..16 }
    net_type: 0..255;                     { bits 17..24 }
    unused_29: 0..127;                    { bits 25..31 }
    unused_2a: integer;                   { 0x2A }
  end;

var
  { APP_$STD_IDP_CHANNEL (map symbol, +0x14 of APP's data segment): the
    standard application IDP channel, 16#FFFF (none) in the image.
    APP_$STD_OPEN stores the opened channel's index; ROUTE_$SERVICE
    passes its address to XNS_IDP_$OS_ADD_PORT / _DELETE_PORT: pinteger
    as xns_$os_open_opt_t's flags_channel.  Defined in app/app.pas. }
  app_$std_idp_channel: extern pinteger;

{ Routine headings, in map order (APP's code segment, WIRED_PROC).  The
  bodies repeat the full heading (ref 7.3.4, Method 2). }

{ APP_$RECEIVE - take the next packet off a socket and describe it. }
procedure app_$receive(sock_num: pinteger; out rec: app_$receive_rec_t;
                       out status: status_$t);
  options(extern, val_param);

{ APP_$DEMUX - queue a packet of the application channel on its socket. }
procedure app_$demux(in pkt: xns_$pkt_desc_t; in port_type: integer;
                     in port_socket: integer; in mac_broadcast: boolean;
                     out status: status_$t); extern;

{ APP_$STD_OPEN - open the standard application IDP channel. }
procedure app_$std_open; extern;

{ ---- APP's dispatch codes, named. ----

  A received packet's network type (APP_$RECEIVE's tests of the routing
  header's net-type byte, `net_type = 1' and `= 2', and its store for an
  XNS packet).  No Apollo insert declares them. }
const
  app_$net_type_local = 1;
  app_$net_type_remote = 2;
{ ---- end of APP's dispatch codes ---- }
