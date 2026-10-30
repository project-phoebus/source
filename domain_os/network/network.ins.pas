{ network/network.ins.pas - NETWORK_ (the network's paging and header
  services), for the Domain Pascal tree.

  What the Pascal files use.  No customer insert file declares these;
  the status texts are the SR10.2 status database's.  Include
  base/base.ins.pas and pkt/pkt.ins.pas before it.
}

const
  { The network statuses NETBUF_ returns or crashes with (stcode.db.10.2,
    "OS / network": 110001 "buffer error", 110003 "out of blocks").
    NETBUF's routines pass the first to CRASH_SYSTEM from a constant
    cell; NETBUF_$GETVA stores the second. }
  status_$network_buffer_error = 16#00110001;
  status_$network_out_of_blocks = 16#00110003;

  { stcode.db.10.2's texts.  NET_IO_$SEND stores the first two (a port
    whose active word is 1, an all-ones source node), and
    NET_IO_$COPY_PACKET the third. }
  status_$network_request_denied_by_local_node = 16#0011000E;
  status_$network_transmit_with_invalid_from_id = 16#00110023;
  status_$network_transmit_failed = 16#00110004;

  { stcode.db.10.2's texts: 110005 "no available socket" (the name says
    otherwise, pkt/README.md), 11000C "no more free sockets",
    110007 "remote node failed to respond to request", 11000A "msg
    header too big", 11001C "data length too large", 11001E "header
    length + data length exceeds max msg size", 110024 "header data
    length exceeds max size allowed". }
  status_$network_receive_process_failed_to_start = 16#00110005;
  status_$network_remote_node_failed_to_respond = 16#00110007;
  status_$network_msg_header_too_big = 16#0011000A;
  status_$network_no_more_free_sockets = 16#0011000C;
  status_$network_data_length_too_large = 16#0011001C;
  status_$network_msg_exceeds_max_size = 16#0011001E;
  status_$network_header_data_length_exceeds_max = 16#00110024;

  { stcode.db.10.2's text: 11001F "no nodeid prom on this system".
    RING_$GET_ID crashes with it (`nodeid_prom'). }
  status_$network_no_nodeid_prom = 16#0011001F;

type
  { One page of the network buffer pool, 0x400 bytes. }
  network_$page_t = array[0..1023] of char;

{ NETWORK_$GETHDR - a packet header page for a send. }
procedure network_$gethdr(in node: integer32; out va: pkt_$hdr_ptr_t;
                          out pa: integer32);
  extern;

{ NETWORK_$RTNHDR - give back a header page NETWORK_$GETHDR handed out. }
procedure network_$rtnhdr(in va: pkt_$hdr_ptr_t); extern;

var
  { NETWORK_$REALLY_DISKLESS (map symbol): a boolean, tested by its sign
    (VOLX_$DISMOUNT; BAT_$N_FREE). }
  network_$really_diskless: extern boolean;

  { NETWORK_$DISKLESS (map symbol, after NETWORK_$REALLY_DISKLESS): a
    boolean, tested by its sign (CAL_$READ_TIMEZONE,
    CAL_$WRITE_TIMEZONE; a caller of CAL_$SHUTDOWN): the node runs
    without a disk of its own. }
  network_$diskless: extern boolean;

  { NETWORK_$LOOPBACK_FLAG (map symbol, in NETWORK's wired data after
    NETWORK_$ACTIVITY_FLAG): a boolean, tested by its sign
    (PKT_$BLD_INTERNET_HDR; true sends every packet to this node). }
  network_$loopback_flag: extern boolean;

  { NETWORK_$BUFPOOL (map symbol, the first of the map's NETPOOL data
    segment and of the load section NETPOOL, 0x30000 bytes): the
    virtual window the network buffers are mapped into, 192 pages, one
    per slot of NETBUF's slot array, indexed from 0. }
  network_$bufpool: extern array[0..191] of network_$page_t;

  { NETPOOL_END (map symbol, at the end of the NETPOOL data segment): the
    end of the network buffer window.  A label the build places: an
    extern char, of which only the address is used (peb/peb.ins.pas's
    markers).  Declared for XNS_ERROR (xns/xns_error.pas). }
  netpool_end: extern char;


const
  { status_$network_unknown_network, 16#00110017 ("unknown network",
    stcode.db.10.2): MSG_$$SEND forgives it for an explicit port
    (PKT_$BLD_INTERNET_HDR's status). }
  status_$network_unknown_network = 16#00110017;

  { NETWORK_$SET_SERVICE's operations: the word its
    first slot points at, read once, and dispatched through a four-entry
    jump table.  MSG_$OPENI and MSG_$ALLOCATEI pass 0 from a constant
    cell, MSG_$CLOSEI 1. }
  network_op_or_bits = 0;
  network_op_and_not_bits = 1;

  { The routing service's member of the service set (bit 3):
    NETWORK_$SET_SERVICE sets it; MSG's value records carry it. }
  network_service_routing = 3;

type
  { The service word, a set: NETWORK_$SET_SERVICE or-s and and-nots it
    into its block's word, and tests members on its low byte. }
  network_$service_set_t = set of 0..15;

  { NETWORK_$SET_SERVICE's value, 4 bytes: the service set (the high
    word) and the remote pool's size (the low word), copied into the
    frame at entry (a value parameter's copy), the set read from the
    copy's first word, the size from its second, sign-extended
    (operation 3). }
  network_$service_t = record
    service: network_$service_set_t;      { 0x00 }
    remote_pool: integer;                 { 0x02 }
  end;

var
  { NETWORK_$USER_SOCK_OPEN (map symbol in NETWORK's block): a boolean,
    set and cleared by MSG_$OPENI and MSG_$CLOSEI; NETWORK_$SET_SERVICE
    reads it (or-ed into a boolean, tested by its sign). }
  network_$user_sock_open: extern boolean;

{ NETWORK_$SET_SERVICE - change the node's allowed network services. }
procedure network_$set_service(in op: integer; value: network_$service_t;
                               out status: status_$t);
  extern;


var
  { NETWORK_$MOTHER_NODE (map symbol in NETWORK's wired block): the mother
    node's ID, a linteger (ASKNODE_$INTERNET_INFO merges it unmasked
    into a 20-bit packed field). }
  network_$mother_node: extern linteger;


const
  { 16#00110018, "too many networks in internet" (stcode.db.10.2, "OS /
    network"): RIP_$UPDATE_INT stores it when the routing table has no
    room for the network; NETWORK_$INSTALL_NET too. }
  status_$network_too_many_networks_in_internet = 16#00110018;


const
  { stcode.db.10.2's texts ("OS / network"): the ring driver passes
    CRASH_SYSTEM 110009 ("network hardware error") from a constant cell
    (ring_$process_rx_packet, ring_$clear_dma_channel), 110010 ("bad
    checksum") and 110013 ("receive bus error") from two
    (ring_$validate_receive), and RING_$SENDP stores 110016 ("memory
    parity error during transmit"). }
  status_$network_hardware_error = 16#00110009;
  status_$network_bad_checksum = 16#00110010;
  status_$network_receive_bus_error = 16#00110013;
  status_$network_memory_parity_error_during_transmit = 16#00110016;

type
  { NETWORK_$FAILURE_REC's record, 16 bytes:
    ring_$validate_receive fills it: the clock's high longword
    (time_$clockh_t), a node, a boolean, the failure type (a header
    longword, linteger as pkt/pkt.ins.pas's nodes).  word0 and byte3 no
    Pascal file names. }
  network_$failure_rec_t = record
    word0: integer;                       { 0x00 }
    flag: boolean;                        { 0x02 }
    byte3: char;                          { 0x03 }
    node_id: linteger;                    { 0x04 }
    timestamp: time_$clockh_t;            { 0x08 }
    failure_type: linteger;               { 0x0C }
  end;

var
  { NETWORK_$ACTIVITY_FLAG (map symbol, in NETWORK's block): a boolean,
    set to true (ring_$process_rx_packet, RING_$RCV_FROM_UNIT_PRIV) and
    from a boolean register (RING_$SENDP). }
  network_$activity_flag: extern boolean;

  { NETWORK_$DO_CHKSUM (map symbol): a boolean, tested by its sign
    (RING_$SENDP), and-ed with another (ring_$validate_receive). }
  network_$do_chksum: extern boolean;

  { NETWORK_$FAILURE_REC (map symbol): the record above, reached by its
    address. }
  network_$failure_rec: extern network_$failure_rec_t;

{ }

type
  { The 32-byte page request NETWORK_$WRITE takes (uid at 0 and page_num
    at 8), also the block header pmap_$write_page passes DISK_$WRITE.
    uid, page_num (linteger: shifted logically) and sub_type are named;
    the rest by offset. }
  network_$page_request_t = record
    uid: uid_$t;                          { 0x00 }
    page_num: linteger;                   { 0x08 }
    reserved_0c: integer32;               { 0x0C }
    reserved_10: char;                    { 0x10 }
    sub_type: char;                       { 0x11 }
    reserved_12: array[16#12..16#19] of char;
                                          { 0x12..0x19 }
    reserved_1a: integer;                 { 0x1A }
    reserved_1c: array[16#1C..16#1F] of char;
                                          { 0x1C..0x1F }
  end;

var
  { NETWORK_$WRITE_VIOL_CNT (map symbol, in NETWORK's block): a word
    counter, incremented in place (pmap_$write_page). }
  network_$write_viol_cnt: extern pinteger;

{ NETWORK_$WRITE - write pages to a remote node's page server. }
procedure network_$write(in node_addr: uid_$t;
                         in req: network_$page_request_t;
                         ppn: linteger; pkt_size: integer;
                         count: pinteger; out dtv_low: pinteger;
                         out dtm: time_$clock_t; out status: status_$t);
  options(extern, val_param);


{ NETWORK_$GET_PKT_SIZE - the packet size to use for a destination. }
function network_$get_pkt_size(in node: uid_$t; size: pinteger): pinteger;
  options(extern, val_param);

{ NETWORK_$DISMISS_REQUEST_SERVERS - stop the request servers. }
procedure network_$dismiss_request_servers; extern;

{ }

const
  { NETWORK_$SET_SERVICE's third operation:
    OS_$SHUTDOWN passes 2 from a constant cell, with a zero value. }
  network_op_set_value = 2;

{ }
var
  { NETWORK_$PAGING_FILE_UID (map symbol, NETWORK's wired data): a
    diskless node's paging file.  OS_$INIT stores the mother node's
    reply into it as two longwords. }
  network_$paging_file_uid: extern uid_$t;

{ NETWORK_$INIT - start the network layer. }
procedure network_$init; extern;

const
  { The most request servers NETWORK_$ADD_REQUEST_SERVERS starts: 3, or
    2 on the SAUs with `two_request_servers' (the SAU5;
    base/config.ins.pas). }
%if two_request_servers %then
  network_$max_request_servers = 2;
%else
  network_$max_request_servers = 3;
%endif

{ NETWORK_$ADD_REQUEST_SERVERS - start request server processes. }
function network_$add_request_servers(in count: integer;
                                      out status: status_$t): integer;
  extern;

{ NETWORK_$LOAD - attach the network service to port 0's driver. }
procedure network_$load; extern;

var
  { NETWORK_$ME (map symbol, at the same address as ROUTE_$PORT, the route
    port table's first element): this node's network, a longword. }
  network_$me: extern integer32;


const
  { NETWORK_$SET_SERVICE's fourth operation: the
    jump table's fourth entry; NETWORK_$INIT passes 3 from a constant
    cell. }
  network_op_set_remote_pool = 3;

  { 16#0011000D, "unknown request type" (stcode.db.10.2, "OS /
    network"): NETWORK_$SET_SERVICE's default arm stores it. }
  status_$network_unknown_request_type = 16#0011000D;

  { 16#0011000F, "request denied by remote node" (stcode.db.10.2, module
    0x11, the text after "request denied by local node"): the page
    server's refusal of a page-in or attribute request. }
  status_$network_request_denied_by_remote_node = 16#0011000F;

type
  { A node's network address as the AST_ and MST_ callers of the network
    table hand it over, 4 bytes: the table index (1..64, 0 for this
    node's own network) in bits 25..20, bits 9..4 of the first word, a
    packed record's 6-bit field. }
  network_$net_addr_t = packed record
    bits_31_26: 0..63;                    { bits 31..26 }
    net_index: 0..63;                     { bits 25..20 }
    bits_19_0: 0..16#FFFFF;               { bits 19..0 }
  end;

  { One entry of the network table, 8 bytes: the
    reference count and the network, the table from 1 at the block's
    +0x40 (network/network.pas). }
  network_$net_entry_t = record
    refcount: integer32;                  { 0x00 }
    net_id: integer32;                    { 0x04 }
  end;

{ NETWORK_$INSTALL_NET - enter a network in the network table. }
procedure network_$install_net(net: integer32;
                               in out addr: network_$net_addr_t;
                               out status: status_$t);
  options(extern, val_param);

{ NETWORK_$REMOVE_NET - give back a network's entry in the network table. }
procedure network_$remove_net(addr: network_$net_addr_t;
                              out status: status_$t);
  options(extern, val_param);

{ NETWORK_$GET_NET - the network an address's index names. }
procedure network_$get_net(addr: network_$net_addr_t; out net_id: integer32;
                           out status: status_$t);
  options(extern, val_param);

{ GET_CHKSUM - the checksum of a page given by its physical address. }
function get_chksum(in pa: integer32; in len: integer): integer32;
  extern;

{ NETWORK_$GET_CHKSUM (hand assembly, network/m68k/get_chksum.s): the
  page's address read off the stack, by value (`val_param', a pointer);
  the sum in D0. }
function network_$get_chksum(page: univ_ptr): integer32;
  options(extern, val_param);

{ NETWORK_$READ_SERVICE - the node's allowed network services. }
procedure network_$read_service(out service: network_$service_t); extern;

{ NETWORK_$ADD_PAGE_SERVERS - start page server processes. }
function network_$add_page_servers(in count: integer;
                                   out status: status_$t): integer;
  extern;

const
  { The service set's members (network_service_routing above):
    NETWORK_$SET_SERVICE tests them on the word's low byte, and
    NETWORK_$READ_SERVICE the third. }
  network_service_paging = 0;
  network_service_file = 1;
  network_service_active = 2;
  network_service_reserved_4 = 4;

{ NETWORK_$PAGE_SERVER - the body of a network page server process.
  NETWORK_$REQUEST_SERVER - the body of a network request server process. }
procedure network_$page_server; extern;
procedure network_$request_server; extern;

type
  { The two backlogs' type, named: ASKNODE_$INTERNET_INFO copies each
    whole into its reply, an assignment that needs one named type on
    both sides (dpc: "not compatible" for two anonymous ones). }
  network_$backlog_t = array[0..8] of integer32;

var
  { The rest of the map symbols of the NETWORK data segment (the block's
    layout: network/network.pas):
    - NETWORK_$PAGING_BACKLOG and _$FILE_BACKLOG: 9 longwords each,
      indexed from 0;
    - NETWORK_$HDR_PAGE_PA and _$HDR_PAGE: the header page's physical
      and virtual addresses;
    - NETWORK_$SERVICE_TIME (16#14), a word, unsigned (pinteger);
    - NETWORK_$REQUEST_SERVER_CNT and _$PAGE_SERVER_CNT: signed words;
    - the counters: words, none signed (pinteger);
    - NETWORK_$ALLOWED_SERVICE: the service and the remote pool;
    - NETWORK_$CLEAR_WIRED: a word counter of the pages the page server
      unwired. }
  network_$paging_backlog: extern network_$backlog_t;
  network_$file_backlog: extern network_$backlog_t;
  network_$hdr_page_pa: extern integer32;
  network_$hdr_page: extern pkt_$hdr_ptr_t;
  network_$service_time: extern pinteger;
  network_$request_server_cnt: extern integer;
  network_$page_server_cnt: extern integer;
  network_$file_over_cnt: extern pinteger;
  network_$rev_2_info_rqst_retry: extern pinteger;
  network_$overflow_reply: extern pinteger;
  network_$rcv_read_ahead: extern pinteger;
  network_$mult_pagin_rqst_cnt: extern pinteger;
  network_$bad_chksum_cnt: extern pinteger;
  network_$read_viol_cnt: extern pinteger;
  network_$read_call_cnt: extern pinteger;
  network_$write_call_cnt: extern pinteger;
  network_$set_attrib_call_cnt: extern pinteger;
  network_$attrib_rqst_cnt: extern pinteger;
  network_$info_rqst_cnt: extern pinteger;
  network_$pagin_rqst_cnt: extern pinteger;
  network_$pagout_rqst_cnt: extern pinteger;
  network_$allowed_service: extern network_$service_t;
  network_$clear_wired: extern pinteger;

  { NETWORK_$2LONG1 (map symbol, in the map's NET_ASM data segment): a
    word counter of replies the page server found too late to send
    (pinteger), reached by its absolute address: another segment's
    variable. }
  network_$2long1: extern pinteger;

const
  { The statuses network_$send_request and network_$do_request store,
    checked against the SR10.2 status text (stcodes, module 0x11):
    "too many transmit retries", "unexpected reply type". }
  status_$network_too_many_transmit_retries = 16#00110011;
  status_$network_unexpected_reply_type = 16#0011000B;
  { The SR10.2 status-code database's "(110015) bad asknode version
    number"; ASKNODE_$INTERNET_INFO stores it when the reply's version is
    neither the request's nor 2. }
  status_$network_bad_asknode_version_number = 16#00110015;
  { The who-listings' three statuses, the SR10.2 status-code database's
    texts "(110019) conflict with another node listing", "(11001a) quit
    fault during node listing" and "(11001b) waited too long for more
    nodes to respond": ASKNODE_$WHO_REMOTE stores the first when
    SOCK_$OPEN of the who socket fails, and the other two at the end of
    its wait; ASKNODE_$WHO_NOTOPO the quit's. }
  status_$network_conflict_with_another_node_listing = 16#00110019;
  status_$network_quit_fault_during_node_listing = 16#0011001A;
  status_$network_waited_too_long_for_more_node_responses = 16#0011001B;

type
  { The page list NETWORK_$READ_AHEAD fills, one physical page number per
    delivered page, from 0.  The bound is the AST's 32 longwords, the
    most one request fetches; the formal `univ'. }
  network_$ppn_list_t = array[0..31] of integer32;

{ NETWORK_$READ_AHEAD - page a run of pages in from a remote node. }
function network_$read_ahead(in node_addr: uid_$t;
                             in out req: network_$page_request_t;
                             out ppn_array: univ network_$ppn_list_t;
                             page_size: pinteger; count: integer;
                             no_read_ahead: boolean; flags: boolean;
                             out dtm: time_$clock_t;
                             out clock: time_$clock_t;
                             out acl_info: time_$clock_t;
                             out status: status_$t): integer;
  options(extern, val_param);

type
  { TODO(merge) move to file/file.ins.pas, as a view of file_$obj_loc_t
    (file/ is the file worktree's): 17 of this file's 25 includers do
    not include file/file.ins.pas.

    The AST's object-location record, 0x20 bytes (the AOTE's +0x9C), as
    NETWORK_$AST_GET_INFO reads and rebuilds it: a packed record, its
    fields MSB first, the two whole bytes pkt/pkt.ins.pas's pkt_$byte_t.
    node_addr is network_$do_request's; no instruction addresses
    bits_1d. }
  network_$obj_loc_t = packed record
    byte_00: pkt_$byte_t;                 { 0x00 }
    hi_01: 0..15;                         { 0x01, bits 7..4 }
    lo_01: 0..15;                         { 0x01, bits 3..0 }
    long_02: integer32;                   { 0x02 }
    word_06: integer;                     { 0x06 }
    uid: uid_$t;                          { 0x08 }
    node_addr: uid_$t;                    { 0x10 }
    long_18: integer32;                   { 0x18 }
    rights: pkt_$byte_t;                  { 0x1C }
    remote: boolean;                      { 0x1D, bit 7 }
    scratch: boolean;                     { 0x1D, bit 6 }
    bits_1d: 0..3;                        { 0x1D, bits 5..4 }
    lo_1d: 0..15;                         { 0x1D, bits 3..0 }
    word_1e: integer;                     { 0x1E }
  end;

  { TODO(merge) move to file/file.ins.pas, as a view of file_$attributes_t
    (file/ is the file worktree's).  The 0x90-byte attribute record (the
    first 0x90 bytes of a VTOCE, vtoc/vtoc.ins.pas vtoce_$t), copied
    whole; member 0 of the set at +0x00 is set after VTOCE_$OLD_TO_NEW.
    The page server reads its first byte as a number: byte_00. }
  network_$attr_rec_t = record
    case integer of
      1: (hdr_bits: set of 0..31;         { 0x00 }
          rest: array[16#04..16#8F] of char);
                                          { 0x04..0x8F }
      2: (byte_00: pkt_$byte_t);          { 0x00 }
  end;

  { An old server's attribute record, 64 bytes (VTOCE_$NEW_TO_OLD's):
    NETWORK_$AST_GET_INFO hands it to VTOCE_$OLD_TO_NEW at reply+6.
    vtoc/vtoc.ins.pas's vtoce_$old_fm_t, 0xCC bytes, does not fit it. }
  network_$old_attr_rec_t = array[1..16] of integer32;

  { The token-ring record NETWORK_$RING_INFO returns, 122 bytes, copied
    whole out of the reply at +6.  Its fields are the server's
    (network_$process_paging_request's case 16#0E).  A record: a record
    assignment copies by longwords, an array of char by bytes. }
  network_$ring_info_t = record
    bytes: array[1..122] of char;         { 0x00..0x79 }
  end;

{ NETWORK_$AST_GET_INFO - fetch a remote object's location and attributes. }
procedure network_$ast_get_info(in out loc: network_$obj_loc_t;
                                in flags: integer;
                                out attrs: network_$attr_rec_t;
                                out status_ret: status_$t); extern;

{ NETWORK_$RING_INFO - fetch a node's token-ring record. }
procedure network_$ring_info(in node_addr: uid_$t;
                             out info: network_$ring_info_t;
                             out status_ret: status_$t); extern;
