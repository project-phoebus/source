{ pkt/pkt.ins.pas - PKT_ (internet packets), for the Domain Pascal tree.

  Only what the Pascal files use: the packet info record, the header
  buffer type, the module's records and variables and the routines'
  headings.  No customer insert file declares these.  Include
  base/base.ins.pas before it.
}

type
  { The packet info record, 0x20 bytes (PKT_$BLD_INTERNET_HDR reads it
    through a held pointer).  NETLOG's block starts with one,
    initialized (netlog/netlog.pas: protocol 16#8031 and field_0c
    16#FFFF, above integer's range).  No ordered compare in the Pascal
    files decides the words' signs. }
  pkt_$info_t = record
    flags: pinteger;                      { 0x00 }
    routing_type: integer;                { 0x02 }
    addr_type: integer;                   { 0x04 }
    protocol: pinteger;                   { 0x06 }
    retry_limit: pinteger;                { 0x08 }
    field_0a: pinteger;                   { 0x0A }
    field_0c: pinteger;                   { 0x0C }
    addr: array[1..16] of char;           { 0x0E }
    pad_1e: integer;                      { 0x1E }
  end;

  { A byte of the packet header read as a number: NET_IO's routines
    zero-extend it before a compare (routing_type, info_0b), and add to
    one in place (route_count). }
  pkt_$byte_t = [byte] 0..255;

  { The 8-bit set in the header's byte 7: NET_IO copies it into a word
    set and tests member 3, the widening of a packed record's small set
    to an unpacked one (ref 3.9.3 p. 3-16: a set takes at least a
    word). }
  pkt_$hdr_bits_t = set of 0..7;

  { The header's longword at +0x04, a packed record.  Byte 4 is the
    packet's type mask, a set of 8, member k bit k: the DN3xx handbook's
    ring TMASK bits (Domain Engineering Handbook, DN3xx chapter, 7-31:
    16#80 broadcast, 16#40
    hardware diagnostic, 16#20 thank you, 16#10 please, 16#08 paging,
    16#04 user, 16#02 software diagnostic, 16#01 xtype3).  Member 7 is
    broadcast (pkt_$hdr_broadcast, at the end of this file): NET_IO,
    ROUTE and the ring driver test it, NET_IO_$SEND and RING_$SEND_OS add
    it, NET_IO_$SEND removes it.  The ring driver also tests members 0, 1
    and 4 and a computed member (ring_$validate_receive), the member test
    of a set in memory on the byte that holds it.  Byte 4 is a set
    rather than a packed boolean at bit 7 and a 7-bit field: no routine
    stores the bit as a value or reads bits 0..6 as a number, and both
    images test bit 7 on the byte, which a packed boolean in the top bit
    of a word's first byte is not.  Bytes 5 and 6 are one 16-bit field
    merged through the longword, a 0..65535 subrange (bit aligned, 16
    bits, at bit 8), here filled with the arrival time's low word; byte
    7 is the small set above.  PKT_$BLD_INTERNET_HDR clears the 16 bits
    and byte 7.  Byte 4 is also written whole, the low byte of the info
    record's flags word (PKT_$BLD_INTERNET_HDR; RING_$SEND_OS and
    RING_$SVC_WRITE store constants), the store of a byte field, as the
    same routine's stores of flags_0e and routing_type are: a variant of
    the same bytes (ref 3.10.3), its field the first byte only
    (info_flags). }
  pkt_$hdr_flags_t = packed record
    case integer of
      1: (info_bits: pkt_$hdr_bits_t;     { +0x04 }
          arrival_lo: pinteger;           { +0x05..+0x06 }
          flags_07: pkt_$hdr_bits_t);     { +0x07 }
      2: (info_flags: pkt_$byte_t);       { +0x04 }
  end;

  { The 12-byte address triple of the internet header, a packed record:
    the node is a 24-bit field read through the longword that holds it
    (masked with 16#FFFFFF), and set whole with an `ori' of every bit
    (NET_IO_$SEND, "Wider field, value" and "the `ori' alone when every
    bit is set"); PKT_$BLD_INTERNET_HDR clears the 24 bits before it.
    The network is the longword at +0, the socket the word at +0xA.  The
    zero and node fields are 24 bits each here. }
  pkt_$inet_addr_t = packed record
    net: integer32;                       { +0x00 }
    zero: 0..16#FFFFFF;                   { +0x04..+0x06 }
    node: 0..16#FFFFFF;                   { +0x07..+0x09 }
    sock: pinteger;                       { +0x0A }
  end;

  { The packet header PKT_$BLD_INTERNET_HDR fills in, 0x5C bytes.  The
    pointer is the type of the header addresses NETWORK_$GETHDR returns
    (network/network.ins.pas).  NET_IO's routines read its fields:
    dest_node at +0, compared and stored; the flags longword at +4
    (above); routing_type, a byte (above); route_count and the 16-bit
    routing words from +0x1E (the 1-based array's bound folded into the
    displacement, route[route_count]); in the internet variant info_0b
    (+0x2C), the destination (+0x2E) and source (+0x3A) addresses.  The
    routing area is a variant part: the route words, a local and an
    internet layout.  The variants' fields that repeat a fixed field's
    name (src_sock, src_node, dest_node_lo, dest_sock) are inet_ and
    local_ prefixed, and data_len is pkt_data_len, which NET_IO_$SEND's
    parameter of that name would otherwise meet inside its `with'
    (net_io/send.pas).  network/network.ins.pas and netlog/send_page.pas
    pass the record whole.  dest_node and src_node are linteger:
    RINGLOG_$LOGIT merges both into 20-bit packed fields unmasked, the
    form of a value whose type admits no negative values
    (pkt_$net_addr_t's node below, NODE_$ME).  The users compare them
    for equality and assign them (NET_IO, ROUTE, RING): the same code
    either way. }
  pkt_$hdr_t = record
    dest_node: linteger;                  { 0x00 }
    flag_bits: pkt_$hdr_flags_t;          { 0x04 }
    src_node: linteger;                   { 0x08 }
    routing_type: pkt_$byte_t;            { 0x0C }
    zero_0d: pkt_$byte_t;                 { 0x0D }
    flags_0e: pkt_$byte_t;                { 0x0E }
    zero_0f: pkt_$byte_t;                 { 0x0F }
    total_len: pinteger;                  { 0x10 }
    template_len: pinteger;               { 0x12 }
    pkt_data_len: pinteger;               { 0x14 }
    request_id: pinteger;                 { 0x16 }
    hdr_size: pkt_$byte_t;                { 0x18 }
    route_count: pkt_$byte_t;             { 0x19 }
    src_sock: pinteger;                   { 0x1A }
    src_node_lo: pinteger;                { 0x1C }
    case integer of
      1: (route: array[1..31] of pinteger);       { 0x1E..0x5B }
      2: (local_dest_node_lo: pinteger;           { 0x1E }
          local_dest_sock: pinteger);             { 0x20 }
      3: (inet_src_sock: pinteger;                { 0x1E }
          inet_src_node: integer32;               { 0x20 }
          inet_dest_node_lo: pinteger;            { 0x24 }
          inet_dest_sock: pinteger;               { 0x26 }
          info_0c: pinteger;                      { 0x28 }
          tpl_len_x: pinteger;                    { 0x2A }
          info_0b: pkt_$byte_t;                   { 0x2C }
          protocol: pkt_$byte_t;                  { 0x2D }
          dest: pkt_$inet_addr_t;                 { 0x2E }
          src: pkt_$inet_addr_t;                  { 0x3A }
          long_request_id: integer32;             { 0x46 }
          subtype: pinteger;                      { 0x4A }
          addr: array[1..16] of char);            { 0x4C..0x5B }
  end;
  pkt_$hdr_ptr_t = ^pkt_$hdr_t;

  { A packet's four payload page addresses, copied as one 16-byte
    object (APP_$RECEIVE, APP_$DEMUX).  From 1: PKT_$DUMP_DATA and
    APP_$DEMUX test the first.  One type for the records that hold it
    (sock/sock.ins.pas, xns/xns.ins.pas, app/app.ins.pas), so that they
    can be assigned to each other's. }
  pkt_$data_pages_t = array[1..4] of integer32;

  {

    The bytes of a buffer the PKT routines copy to or from, the formal
    type of their `univ' buffer parameters, and the bytes of a header
    seen as one array.  1-based: PKT_$BLD_INTERNET_HDR and
    _$BRK_INTERNET_HDR address the template behind the header as byte
    number hdr_size + 0x1F (the template starts at header + hdr_size +
    0x1F - 1).  A header page is 0x400 bytes (network/network.ins.pas
    network_$page_t; ref 5.3.3 for `univ'). }
  pkt_$bytes_t = array[1..1024] of char;
  pkt_$bytes_ptr_t = ^pkt_$bytes_t;

  { The network and node PKT_$LIKELY_TO_ANSWER is asked about.  The node
    goes unmasked into a 20-bit packed field, the form for a value whose
    type admits no negative values: linteger, as node/node.ins.pas's
    NODE_$ME.  PKT_$SAR_INTERNET builds one in its frame from its
    routing key and node. }
  pkt_$net_addr_t = record
    network: integer32;                   { 0x00 }
    node: linteger;                       { 0x04 }
  end;

  { The header APP_$RECEIVE's record points at with its reply field
    (app/app.ins.pas app_$receive_rec_t), as the PKT routines read it:
    hdr_len at 2 and data_len at 4, compared unsigned (PKT_$PING_SERVER,
    PKT_$SAR_INTERNET); request_id at 6, compared for equality with
    PKT_$NEXT_ID's; src_node at 0xE and src_sock at 0x12, copied; flags
    at 0x14, a byte widened.  The longword at 0xE is word aligned (the
    kernel's word rules).  dest_node at 8: the node the request was sent
    to, which APP_$RECEIVE stores there for a local network
    (app/receive.pas p_src_node := node_$me, app/app.ins.pas
    app_$pkt_hdr_t's view of the same header), and ASKNODE_$SERVER reads
    as a longword, passing it as its reply's PKT_$SEND_INTERNET
    src_node: integer32 as src_node.  The name is the request's view, as
    src_node's. }
  pkt_$internet_hdr_t = record
    unused_00: integer;                   { 0x00 }
    hdr_len: pinteger;                    { 0x02 }
    data_len: pinteger;                   { 0x04 }
    request_id: pinteger;                 { 0x06 }
    dest_node: integer32;                 { 0x08 }
    unused_0c: integer;                   { 0x0C }
    src_node: integer32;                  { 0x0E }
    src_sock: pinteger;                   { 0x12 }
    flags: pkt_$byte_t;                   { 0x14 }
  end;
  pkt_$internet_hdr_ptr_t = ^pkt_$internet_hdr_t;

  { PKT_$SAR_INTERNET's tenth argument: the routine writes only the word
    at 8, the number of attempts. }
  pkt_$sar_result_t = record
    unused_00: array[0..7] of char;       { 0x00 }
    attempts: integer;                    { 0x08 }
  end;

  { An entry of the list of nodes that failed to answer, 8 bytes.  The
    node compared for equality only; the sequence number compared
    unsigned: linteger. }
  pkt_$missing_entry_t = record
    node_id: linteger;                    { 0x00 }
    seq_number: linteger;                 { 0x04 }
  end;

var
  { PKT_$MISSING_NODE and PKT_$N_MISSING (map symbols, +0x00 and +0x58
    of PKT's WIRED_DATA block; defined in pkt/pkt.pas): the list and its
    length.  From 1: PKT_$NOTE_VISIBLE and _$RECENTLY_MISSING walk it
    with a pointer one element in, and index element k with the bound
    folded in; ten elements (the count compared with 10, against the
    0x58 bytes before it).  The count a signed word. }
  pkt_$missing_node: extern array[1..10] of pkt_$missing_entry_t;
  pkt_$n_missing: extern integer;

{ PKT_$BLD_INTERNET_HDR - build a Domain internet packet header. }
procedure pkt_$bld_internet_hdr(routing_key: integer32;
                                dest_node: linteger;
                                dest_sock: integer;
                                src_node_or: integer32;
                                src_node: linteger;
                                src_sock: integer;
                                in pkt_info: univ pkt_$info_t;
                                request_id: pinteger;
                                in template: univ pkt_$hdr_t;
                                template_len: pinteger;
                                data_len: pinteger;
                                in out port_out: integer;
                                out hdr: univ pkt_$hdr_t;
                                out len_out: integer;
                                out retry_hint: integer;
                                out timeout_out: pinteger;
                                out status_ret: status_$t);
  options(extern, val_param);

{ The other headings, in map order (WIRED_PROC, then OS_INIT_PROC, then
  PROCEDURE$).  The bodies are in pkt/*.pas and repeat the full
  headings. }

{ PKT_$BRK_INTERNET_HDR - take a received packet header apart. }
procedure pkt_$brk_internet_hdr(in hdr: pkt_$hdr_t;
                                hdr_len: integer;
                                out routing_key: integer32;
                                out dest_node: integer32;
                                out dest_sock: pinteger;
                                out src_node_or: integer32;
                                out src_node: linteger;
                                out src_sock: pinteger;
                                out info_out: pkt_$info_t;
                                out id_out: pinteger;
                                out data_buf: univ pkt_$bytes_t;
                                data_max: pinteger;
                                in out data_len: pinteger;
                                out status_ret: status_$t);
  options(extern, val_param);

{ PKT_$NEXT_ID - the next short packet id.
  PKT_$NEXT_LONG_ID - the next long packet id. }
function pkt_$next_id: pinteger; extern;
function pkt_$next_long_id: integer32; extern;

{ PKT_$COPY_TO_PA - copy a packet's data into network data pages. }
procedure pkt_$copy_to_pa(in src_va: univ pkt_$bytes_t; len: integer;
                          out buffers_out: pkt_$data_pages_t;
                          out status_ret: status_$t);
  options(extern, val_param);

{ PKT_$SEND_INTERNET - send an internet packet, with retries. }
procedure pkt_$send_internet(routing_key: integer32;
                             dest_node: integer32;
                             dest_sock: integer;
                             src_node_or: integer32;
                             src_node: integer32;
                             src_sock: integer;
                             in pkt_info: univ pkt_$info_t;
                             request_id: pinteger;
                             in template: univ pkt_$bytes_t;
                             template_len: pinteger;
                             in data: univ pkt_$bytes_t;
                             data_len: integer;
                             out retry_hint: integer;
                             out timeout_out: pinteger;
                             out status_ret: status_$t);
  options(extern, val_param);

{ PKT_$DUMP_DATA - give a packet's data pages back. }
procedure pkt_$dump_data(in buffers: pkt_$data_pages_t; len: integer);
  options(extern, val_param);

{ PKT_$DAT_COPY - copy a packet's data out of its data pages. }
procedure pkt_$dat_copy(in buffers: pkt_$data_pages_t; len: integer;
                        dest_va: integer32);
  options(extern, val_param);

{ PKT_$RECENTLY_MISSING - is a node on the list of nodes that failed to
  answer?
  PKT_$NOTE_VISIBLE - record whether a node answered. }
function pkt_$recently_missing(node_id: linteger): boolean;
  options(extern, val_param);
procedure pkt_$note_visible(node: linteger; is_visible: boolean);
  options(extern, val_param);

{ PKT_$LIKELY_TO_ANSWER - is a node likely to answer a request? }
function pkt_$likely_to_answer(in addr_info: univ pkt_$net_addr_t;
                               out status_ret: status_$t): boolean;
  extern;

{ PKT_$PING_SERVER - the ping server process. }
procedure pkt_$ping_server; extern;

{ PKT_$INIT - start the ping server. }
procedure pkt_$init; extern;

{ PKT_$SAR_INTERNET - send an internet request and wait for its reply. }
procedure pkt_$sar_internet(routing_key: integer32;
                            dest_node: integer32;
                            dest_sock: integer;
                            in pkt_info: univ pkt_$info_t;
                            timeout: pinteger;
                            in req_template: univ pkt_$bytes_t;
                            req_tpl_len: pinteger;
                            in req_data: univ pkt_$bytes_t;
                            req_data_len: integer;
                            out resp_buf: pkt_$sar_result_t;
                            out resp_tpl_buf: univ pkt_$bytes_t;
                            resp_tpl_max: pinteger;
                            out resp_tpl_len: integer;
                            out resp_data_buf: univ pkt_$bytes_t;
                            resp_data_max: pinteger;
                            out resp_data_len: pinteger;
                            out status_ret: status_$t);
  options(extern, val_param);

{ ---- PKT's dispatch codes, named. ----

  A packet's routing type (pkt_$info_t's routing_type at +0x02, and the
  low byte pkt_$hdr_t keeps at +0x0C; PKT_$BLD_INTERNET_HDR's and
  PKT_$BRK_INTERNET_HDR's tests, NET_IO's, RING_$INT's and
  ROUTE_$PROCESS's): local and internet.

  Its address type (pkt_$info_t's addr_type at +0x04; 2 means a long,
  16-byte address is present).

  The header subtype that carries the 16-byte address
  (PKT_$BLD_INTERNET_HDR's `hdr.subtype = 16#29'); msg/msg.ins.pas names
  the same code msg_proto_subtype_inet, for the protocol MSG sends with
  it.

  No Apollo insert declares them. }
const
  pkt_$routing_local = 1;
  pkt_$routing_inet = 2;

  pkt_$addr_short = 1;
  pkt_$addr_long = 2;

  pkt_$subtype_long_addr = 16#29;
{ ---- end of PKT's dispatch codes ---- }

{ The broadcast member of the header's type mask, pkt_$hdr_flags_t's
  info_bits (16#80, the handbook's TMASK "broadcast"). }
const
  pkt_$hdr_broadcast = 7;
