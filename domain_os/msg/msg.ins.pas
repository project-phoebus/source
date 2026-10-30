{ msg/msg.ins.pas - MSG (message sockets), for the Domain Pascal tree.

  The statuses, limits, template, packet-info and address records, the
  send report's view, the MSG_WIRED variables and every MSG global's
  heading, in map order; the modules are msg/msg_wired.pas and
  msg/msg_unwired.pas.  No customer insert file declares MSG.

  Include base/base.ins.pas, ml/ml.ins.pas, ec/ec.ins.pas and
  pkt/pkt.ins.pas before it.
}

const
  { The statuses of the OS / msg manager (stcode.db.10.2: 290001 "socket
    out of range", 290002 "too deep", 290004 "no more sockets", 290005
    "not owner", 290008 "socket in use", 290009 "time out", 29000A "quit
    fault").  Stored by MSG_$OPENI, _$ALLOCATEI, _$SARI, _$CLOSEI,
    _$WAITI. }
  status_$msg_socket_out_of_range = 16#00290001;
  status_$msg_too_deep = 16#00290002;
  status_$msg_no_more_sockets = 16#00290004;
  status_$msg_no_owner = 16#00290005;
  status_$msg_socket_in_use = 16#00290008;
  status_$msg_time_out = 16#00290009;
  status_$msg_quit_fault = 16#0029000A;

  { The highest socket number, 0xE0, the bound of MSG's two tables and of
    the routines' range checks (every check `<=' but MSG_$OPENI's `<'),
    and of the loops of MSG_$FORK and MSG_$FREE_ASID. }
  msg_max_socket = 16#E0;

  { The deepest socket queue (MSG_$OPENI, MSG_$ALLOCATEI). }
  msg_max_depth = 32;

  { The longest template MSG_$$SEND builds a header for, and the longest
    data that fit the bounce page, both compared unsigned. }
  msg_max_template_len = 512;
  msg_dpage_max_data = 16#400;

  { The member of the packet info's flag set that MSG_$$SEND adds (bit 2
    of the word). }
  msg_info_flag_msg = 2;

  { The member of the send report's flag word that marks a packet a
    socket of this node took: tested as the word's sign (MSG_$$SEND). }
  msg_xmit_queued = 15;

  { The protocol pair that makes the receive routines take a 16-byte
    internet address off the front of the template (msg_$$rcv_internal). }
  msg_proto_type_inet = 2;
  msg_proto_subtype_inet = 16#29;

type
  { A set of address spaces, 64 members (the ASIDs 0..63, 8-byte
    ownership masks): the MSG routines test PROC1_$AS_ID's member with
    the byte offset (63 - k) >> 3, and build `[k]' in an 8-byte frame
    temporary: a 64-element set, as MST_$ALLOC_ASID tests one. }
  msg_$asid_set_t = set of 0..63;

  { An element of the ownership table, 8 bytes: a record of the one set.
    MSG_$FORK and MSG_$FREE_ASID walk the table with a pointer and copy
    it at the loop head before reaching the set through the copy: the
    `with a[i] do' form (its body copies the pointer at the head), which
    takes a record.  Each of those frames has the 4 bytes of a `with'
    temporary. }
  msg_$owner_t = record
    owners: msg_$asid_set_t;              { 0x00 }
  end;

  { The packet info's flags word as MSG uses it, a word set: MSG_$$SEND
    adds member 2 in place, MSG_$SEND and MSG_$SAR store the caller's
    word over it. }
  msg_$info_flags_t = set of 0..15;

  { The 30-byte packet info template: the MSG_UNWIRED block's first
    object, copied whole into the frame as seven longwords and a word
    (MSG_$SEND, MSG_$SAR; MSG_$$SEND from its parameter).  A record
    assignment copies its type whole, so the type is 30 bytes:
    pkt/pkt.ins.pas pkt_$info_t without pad_1e (its names and offsets),
    the flags a word set (above).  REM_NAME's template is the same 30
    bytes (rem_name/rem_name.ins.pas rem_name_$config_t; the TODO(pascal)
    in rem_name/send_request.pas). }
  msg_$template_t = record
    flags: msg_$info_flags_t;             { 0x00 }
    routing_type: integer;                { 0x02 }
    addr_type: integer;                   { 0x04 }
    protocol: pinteger;                   { 0x06 }
    retry_limit: pinteger;                { 0x08 }
    field_0a: pinteger;                   { 0x0A }
    field_0c: pinteger;                   { 0x0C }
    addr: array[1..16] of char;           { 0x0E }
  end;

  { The transmit status word of the send report, as MSG writes it: a
    packed record (ref 3.10.7) with a set view.  MSG_$$SEND clears it,
    sets bit 3 (a boolean field, constant, on its byte), stores
    SOCK_$PUT's boolean into bit 15 (a boolean field, value, at bit 7 of
    the byte), and tests bit 15 as the word's sign (a word set's member
    15; a boolean field is tested on its byte).  net_io/net_io.ins.pas
    net_io_$send_info_t's xmit_status, a pinteger, is the same word
    (NET_IO_$SEND sets bits 15 and 3). }
  msg_$xmit_flags_t = packed record
    case integer of
      1: (queued: boolean;                { bit 15 }
          unused_14: 0..2047;             { bits 14..4 }
          local: boolean;                 { bit 3 }
          unused_02: 0..7);               { bits 2..0 }
      2: (bits: set of 0..15);
  end;

  { NET_IO_$SEND's report as MSG_$$SEND hands it back
    (net_io/net_io.ins.pas net_io_$send_info_t, its layout and its first
    field's name): the port's network type and the transmit status
    (above).  MSG_$$SEND copies NET_IO_$SEND's record over it as one
    longword: a record assignment, the type transfer of a record of the
    same size (ref 4, "Type Transfer Functions"). }
  msg_$send_info_t = record
    port_net: integer;                    { 0x00 }
    xmit: msg_$xmit_flags_t;              { 0x02 }
  end;

  { An internet address, 16 bytes, copied one byte at a time
    (msg_$$rcv_internal, MSG_$RCV_CONTIGI): a character array (a record
    would be copied by longwords). }
  msg_$inet_addr_t = array[1..16] of char;
  msg_$inet_addr_ptr_t = ^msg_$inet_addr_t;

  { The sender's protocol and address record the receive routines fill:
    the words at 0..6 stored from the reply's bytes zero-extended, flags
    from the receive record, reserved2 and reserved3 in one longword
    store, the address from 0xE.  MSG_$SEND_HW reads proto_subtype as a
    word and reserved1 sign-extended: reserved1 integer, the others
    pinteger.  30 bytes: no instruction copies the record whole or
    reaches past +0x1D.  MSG_$RCV, MSG_$RCV_CONTIG and MSG_$SAR have it
    two bytes below the top of their frames, where 8-byte alignment of
    an object of 8 bytes or more puts it (the 30-byte template sits so
    too; msg/msg_unwired.pas, its TODO(pascal) on the frames). }
  msg_$hw_addr_t = record
    proto_family: pinteger;               { 0x00 }
    flags: pinteger;                      { 0x02 }
    proto_type: pinteger;                 { 0x04 }
    proto_subtype: pinteger;              { 0x06 }
    reserved1: integer;                   { 0x08 }
    reserved2: pinteger;                  { 0x0A }
    reserved3: pinteger;                  { 0x0C }
    inet_addr: msg_$inet_addr_t;          { 0x0E }
  end;

  { The reply header APP_$RECEIVE's record points at, as MSG reads it (the
    bytes APP_$RECEIVE builds, app/app.ins.pas app_$pkt_hdr_t): the
    template length at 2, compared unsigned and lowered in place; the
    data length at 4, compared unsigned; the request id at 6; the nodes
    and sockets at 8, 0xC, 0xE, 0x12, copied out; the three protocol
    bytes at 0x14..0x16, zero-extended.  The longword at 0xE is word
    aligned.  The word at 0 is never read. }
  msg_$reply_hdr_t = record
    unused_00: integer;                   { 0x00 }
    template_len: pinteger;               { 0x02 }
    data_len: pinteger;                   { 0x04 }
    request_id: pinteger;                 { 0x06 }
    dest_node: linteger;                  { 0x08 }
    dest_sock: pinteger;                  { 0x0C }
    src_node: linteger;                   { 0x0E }
    src_sock: pinteger;                   { 0x12 }
    proto_family: pkt_$byte_t;            { 0x14 }
    proto_type: pkt_$byte_t;              { 0x15 }
    proto_subtype: pkt_$byte_t;           { 0x16 }
  end;
  msg_$reply_hdr_ptr_t = ^msg_$reply_hdr_t;

var
  { The MSG_WIRED block's map symbols (the MSG_WIRED data segment,
    WIRED_DATA), defined in msg/msg_wired.pas: MSG_$SOCK_LOCK (+0x00),
    the exclusion lock of the socket tables, whose address MSG_UNWIRED's
    routines push (another unit's variable); DPAGE_VA (+0x14) and
    DPAGE_PA (+0x18), the bounce page's addresses (MSG_$INIT);
    DPAGE_LOCK (+0x1C), its claim count, incremented and tested as a
    word: an integer.  The three without `$' are globals all the same.
    The page addresses are integer32 (NETBUF_$GET_DAT's and
    NETBUF_$GETVA's `out' formals). }
  msg_$sock_lock: extern ml_$exclusion_t;
  dpage_va: extern integer32;
  dpage_pa: extern integer32;
  dpage_lock: extern integer;

{ Routine headings, in map order: MSG_WIRED (WIRED_PROC) and MSG_UNWIRED
  (OS_INIT_PROC, .TEXT, PROC2_CREATE_PRO, PROC2_DELETE_PRO).  The bodies
  repeat the full headings (ref 7.3.4, Method 2).  The user calls (every
  .TEXT global) are SVC entries: their addresses are cells of the SVC
  tables, so they have the default convention, every argument by
  address; a scalar read through its slot without a copy is `in', one
  copied into the frame at entry a value parameter. }

{ MSG_$$SEND - build a message's packet header and queue it on a local
  socket or hand it to the network. }
procedure msg_$$send(port_num: integer;
                     routing_key: integer32;
                     dest_node: linteger;
                     dest_sock: pinteger;
                     src_node_or: integer32;
                     src_node: linteger;
                     src_sock: pinteger;
                     in pkt_info: msg_$template_t;
                     request_id: pinteger;
                     in template: univ pkt_$bytes_t;
                     template_len: pinteger;
                     in data: univ pkt_$bytes_t;
                     data_len: pinteger;
                     out send_info: msg_$send_info_t;
                     out status_ret: status_$t);
  options(extern, val_param);

{ MSG_$INIT - set up MSG at boot: the bounce page, the socket lock and the
  reserved sockets' owner. }
procedure msg_$init; extern;

{ MSG_$GET_MY_NET - this node's network.
  MSG_$GET_MY_NODE - this node's id. }
procedure msg_$get_my_net(out net_id: integer32); extern;
procedure msg_$get_my_node(out node_id: linteger); extern;

{ MSG_$SET_HPIPC - check that the calling address space owns a socket. }
procedure msg_$set_hpipc(in socket: integer; var param2: integer32;
                         out status_ret: status_$t);
  extern;

{ MSG_$OPEN - open a socket by number (the two-argument SVC form).
  MSG_$OPENI - open a socket by number. }
function msg_$open(in socket: integer; in depth: integer): boolean;
  extern;
procedure msg_$openi(in socket: integer; in depth: integer;
                     out status_ret: status_$t);
  extern;

{ MSG_$ALLOCATE - allocate a user socket (the two-argument SVC form).
  MSG_$ALLOCATEI - allocate a user socket. }
function msg_$allocate(out socket: pinteger; in depth: integer): boolean;
  extern;
procedure msg_$allocatei(out socket: pinteger; in depth: integer;
                         out status_ret: status_$t);
  extern;

{ MSG_$CLOSE - close a socket (the one-argument SVC form).
  MSG_$CLOSEI - give up the calling address space's share of a socket. }
procedure msg_$close(in socket: integer); extern;
procedure msg_$closei(in socket: integer; out status_ret: status_$t);
  extern;

{ MSG_$RCV - receive a message (the short SVC form).
  MSG_$RCVI - receive a message. }
procedure msg_$rcv(in socket: integer;
                   out src_node: linteger;
                   out src_sock: pinteger;
                   out proto_family_ret: pinteger;
                   out msg_type: pinteger;
                   out template: univ pkt_$bytes_t;
                   in template_max: pinteger;
                   out template_len_ret: pinteger;
                   out data: univ pkt_$bytes_t;
                   in data_max: pinteger;
                   out data_len_ret: pinteger;
                   out status_ret: status_$t);
  extern;
procedure msg_$rcvi(in socket: integer;
                    out dest_net: integer32;
                    out dest_node: linteger;
                    out dest_sock: pinteger;
                    out src_net: integer32;
                    out src_node: linteger;
                    out src_sock: pinteger;
                    out hw_addr: msg_$hw_addr_t;
                    out msg_type: pinteger;
                    out template: univ pkt_$bytes_t;
                    in template_max: pinteger;
                    out template_len_ret: pinteger;
                    out data: univ pkt_$bytes_t;
                    in data_max: pinteger;
                    out data_len_ret: pinteger;
                    out status_ret: status_$t);
  extern;

{ MSG_$RCV_CONTIG - receive a message into one buffer (the short SVC
  form).
  MSG_$RCV_CONTIGI - receive a message into one buffer, the template and
  the data after it. }
procedure msg_$rcv_contig(in socket: integer;
                          out src_node: linteger;
                          out src_sock: pinteger;
                          out proto_family_ret: pinteger;
                          out msg_type: pinteger;
                          data_buf: pkt_$bytes_ptr_t;
                          in max_len: pinteger;
                          out data_len: pinteger;
                          out status_ret: status_$t);
  extern;
procedure msg_$rcv_contigi(in socket: integer;
                           out dest_net: integer32;
                           out dest_node: linteger;
                           out dest_sock: pinteger;
                           out src_net: integer32;
                           out src_node: linteger;
                           out src_sock: pinteger;
                           out hw_addr: msg_$hw_addr_t;
                           out msg_type: pinteger;
                           out data_buf: univ pkt_$bytes_t;
                           in max_len: pinteger;
                           out data_len: pinteger;
                           out status_ret: status_$t);
  extern;

{ MSG_$RCV_HW - receive a message, with the header page's two eventcount
  words. }
procedure msg_$rcv_hw(in socket: integer;
                      out src_node: linteger;
                      out src_sock: pinteger;
                      out proto_family_ret: pinteger;
                      out msg_type: pinteger;
                      out template: univ pkt_$bytes_t;
                      in template_max: pinteger;
                      out template_len_ret: pinteger;
                      out data: univ pkt_$bytes_t;
                      in data_max: pinteger;
                      out data_len_ret: pinteger;
                      out ec_param1_ret: integer;
                      out ec_param2_ret: pinteger;
                      out status_ret: status_$t);
  extern;

{ MSG_$SEND - send a message to a socket of a node with MSG's template. }
procedure msg_$send(dest_node: linteger;
                    dest_sock: pinteger;
                    src_sock: pinteger;
                    info_flags: msg_$info_flags_t;
                    request_id: pinteger;
                    in template: univ pkt_$bytes_t;
                    template_len: pinteger;
                    in data: univ pkt_$bytes_t;
                    data_len: pinteger;
                    out xmit_status: msg_$xmit_flags_t;
                    out status_ret: status_$t);
  extern;

{ MSG_$SENDI - send a message with the caller's addresses and template. }
procedure msg_$sendi(in routing_key: integer32;
                     in dest_node: linteger;
                     in dest_sock: pinteger;
                     in src_node_or: integer32;
                     in src_node: linteger;
                     in src_sock: pinteger;
                     in pkt_info: msg_$template_t;
                     in request_id: pinteger;
                     in template: univ pkt_$bytes_t;
                     in template_len: pinteger;
                     in data: univ pkt_$bytes_t;
                     in data_len: pinteger;
                     out xmit_status: msg_$xmit_flags_t;
                     out status_ret: status_$t);
  extern;

{ MSG_$SEND_HW - send a message through the port of a given network and
  socket. }
procedure msg_$send_hw(in hw_addr: msg_$hw_addr_t;
                       in routing_key: integer32;
                       in dest_node: linteger;
                       in dest_sock: pinteger;
                       in src_node_or: integer32;
                       in src_node: linteger;
                       in src_sock: pinteger;
                       in pkt_info: msg_$template_t;
                       in request_id: pinteger;
                       in template: univ pkt_$bytes_t;
                       in template_len: pinteger;
                       in data: univ pkt_$bytes_t;
                       in data_len: pinteger;
                       out send_info: msg_$send_info_t;
                       out status_ret: status_$t);
  extern;

{ MSG_$WAIT - wait for a message on a socket (the two-argument SVC form).
  MSG_$WAITI - wait for a message on a socket, a timeout or a quit. }
function msg_$wait(in socket: integer; in timeout: pinteger): boolean;
  extern;
procedure msg_$waiti(in socket: integer; in timeout: pinteger;
                     out status_ret: status_$t);
  extern;

{ MSG_$GET_EC - a level-2 eventcount for a socket's messages. }
procedure msg_$get_ec(in socket: integer; out ec: ec2_$ptr_t;
                      out status_ret: status_$t);
  extern;

{ MSG_$SAR - send a request and wait for its reply, with MSG's template
  (the short SVC form).
  MSG_$SARI - send a request and wait for its reply. }
procedure msg_$sar(in timeout: integer;
                   in dest_node: linteger;
                   in dest_sock: pinteger;
                   in flags: msg_$info_flags_t;
                   in send_template: univ pkt_$bytes_t;
                   in send_template_len: pinteger;
                   in send_data: univ pkt_$bytes_t;
                   in send_data_len: pinteger;
                   out xmit_status_ret: msg_$xmit_flags_t;
                   out proto_family_ret: pinteger;
                   out rcv_template: univ pkt_$bytes_t;
                   in rcv_template_max: pinteger;
                   out rcv_template_len_ret: pinteger;
                   out rcv_data: univ pkt_$bytes_t;
                   in rcv_data_max: pinteger;
                   out rcv_data_len_ret: pinteger;
                   out status_ret: status_$t);
  extern;
procedure msg_$sari(in timeout: integer;
                    in routing_key: integer32;
                    in dest_node: linteger;
                    in dest_sock: pinteger;
                    in pkt_info: msg_$template_t;
                    in send_template: univ pkt_$bytes_t;
                    in send_template_len: pinteger;
                    in send_data: univ pkt_$bytes_t;
                    in send_data_len: pinteger;
                    out xmit_status_ret: msg_$xmit_flags_t;
                    out hw_addr: msg_$hw_addr_t;
                    out rcv_template: univ pkt_$bytes_t;
                    in rcv_template_max: pinteger;
                    out rcv_template_len_ret: pinteger;
                    out rcv_data: univ pkt_$bytes_t;
                    in rcv_data_max: pinteger;
                    out rcv_data_len_ret: pinteger;
                    out status_ret: status_$t);
  extern;

{ MSG_$TEST_FOR_MESSAGE - whether a socket has a message queued. }
function msg_$test_for_message(in socket: integer; out ec_value: integer32;
                               out status_ret: status_$t): boolean;
  extern;

{ MSG_$SHARE_SOCKET - add a process's address space to a socket's owners,
  or take it away. }
procedure msg_$share_socket(in socket: integer; in proc_uid: uid_$t;
                            in add_remove: integer;
                            out status_ret: status_$t);
  extern;

{ MSG_$FORK - give a new address space its parent's share of every socket. }
function msg_$fork(in parent_asid: integer; in child_asid: integer): boolean;
  extern;

{ MSG_$FREE_ASID - close an address space's share of every socket. }
procedure msg_$free_asid(in asid: integer); extern;
