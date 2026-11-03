{ network/network.pas - the NETWORK module: the network table, the
  header page, the service word, and the network's page and request
  servers.

  Image addresses:
    sau2  0x00E248FC  NETWORK data (WIRED_DATA, 0x364 bytes)
    sau8  0x03C269A4  NETWORK data (WIRED_DATA, 0x364 bytes)

  One compilation unit: the map's NETWORK code segments in WIRED_PROC
  (0x2DD0 bytes, network_$phys_copy .. NETWORK_$REQUEST_SERVER),
  OS_INIT_PROC (0x1C8 bytes, NETWORK_$INIT, NETWORK_$LOAD) and
  PROCEDURE$ (0x148 bytes, NETWORK_$READ_SERVICE ..
  NETWORK_$DISMISS_REQUEST_SERVERS), and its data segment in WIRED_DATA
  (0x364 bytes).

  The map's NETWORK_ASM code segment (0xB8 bytes) is hand assembly
  (network/m68k/get_chksum.s; OS_$DATA_COPY and OS_$DATA_ZERO,
  os/README.md).  network/fetch_diskless_info.pas is the OS
  module's, included by os/os.pas.

  The heading names the WIRED sections, `module network, wired_proc,
  wired_data;' (LOG_'s and AREA_'s shape); the other sections' routines
  are headed `[section(os_init_proc, os_init_data)]' and
  `[section(procedure$, data$)]'.

  The block, 0x364 bytes, all zero but where shown:

    +0x000  network_$server_pkt_info, a pkt_$info_t (initialized)
    +0x020  network_$request_pkt_info (initialized)
    +0x040  network_$net_table[1..64], 8 bytes each: the refcount and
            the network
    +0x240  REM_FILE_$SOCK_LOCK (map symbol), an ml_$exclusion_t of 0x12
            bytes

    +0x252  6 bytes nothing addresses (the stand-in unused_252; TODO)
    +0x258  network_$rqst_done_ec, an eventcount, its waiter list
            pointing at itself
    +0x264  4 bytes nothing addresses (the stand-in unused_264)
    +0x268  network_$rqst_quit_ec, the same
    +0x274  4 bytes nothing addresses (the stand-in unused_274)

    +0x278  network_$rqst_wait[1..4], longwords
    +0x288  8 bytes nothing addresses (the stand-in unused_288; TODO)
    +0x290  network_$page_wait[1..4], longwords
    +0x2A0  network_$zero_page_pa, a longword
    +0x2A4  network_$lock, the spin lock's longword
    +0x2A8  network_$ring_dcte, a DCTE pointer

    +0x2AC  4 bytes nothing addresses (the stand-in unused_2ac; TODO)
    +0x2B0  NETWORK_$PAGING_BACKLOG, 9 longwords (map symbol)
    +0x2D4  NETWORK_$FILE_BACKLOG, 9 longwords (map symbol)
    +0x2F8  NETWORK_$FAILURE_REC (map symbol), 16 bytes, its first word 2
    +0x308  NETWORK_$HDR_PAGE_PA, NETWORK_$HDR_PAGE (map symbols)
    +0x310  NETWORK_$MOTHER_NODE (map symbol)

    +0x314  NETWORK_$PAGING_FILE_UID (map symbol), 8 bytes
    +0x31C  NETWORK_$SERVICE_TIME (map symbol), 16#14
    +0x31E  network_$age_ticks, a word
    +0x320  NETWORK_$REQUEST_SERVER_CNT .. _$PAGOUT_RQST_CNT, 17 words
            (map symbols)
    +0x342  NETWORK_$ALLOWED_SERVICE (map symbol), 4 bytes

    +0x346  NETWORK_$ACTIVITY_FLAG, _$LOOPBACK_FLAG, _$DO_CHKSUM,
            _$USER_SOCK_OPEN, _$REALLY_DISKLESS, _$DISKLESS: booleans,
            one per word (each symbol 2 bytes after the last)
    +0x352  2 bytes: the clock's alignment
    +0x354  network_$retry_delay, a clock, 16#9C4

    +0x35A  network_$request_send_flags 1, network_$report_send_flags 0,
            network_$reply_send_flags 0
    +0x360  NETWORK_$CLEAR_WIRED (map symbol), a word
    +0x362  network_$std_open_flag, a boolean, true
    +0x363  1 byte: the block's rounding

  The routines live in one fragment file each, included below in image
  order (network/README.md has the map).

  Build: dpc -I domain_os domain_os/network/network.pas.  Check:
  tools/pascal_check.sh.
}
module network, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'node/node.ins.pas';
%include 'asknode/asknode.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'acl/acl.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'hint/hint.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'route/route.ins.pas';
%include 'rip/rip.ins.pas';
%include 'msg/msg.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'ring/ring.ins.pas';
%include 'ring/ring_driver.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';
%include 'app/app.ins.pas';
%include 'os/os.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'area/area.ins.pas';
%include 'anon/anon.ins.pas';

const
  { The paging protocol's request types, the page server's dispatch
    (network_$process_paging_request's `case rqst.ps.op', a jump table)
    and what the clients store (NETWORK_$WRITE 4, NETWORK_$AST_GET_INFO
    6, NETWORK_$READ_AHEAD 16#0C, NETWORK_$RING_INFO 16#0E).  Each
    reply's type is its request's plus 1 (network_$do_request tests
    `resp_buf.op <> cmd_buf.op + 1'). }
  network_ps_rqst_echo = 0;
  network_ps_rqst_pagout = 4;
  network_ps_rqst_getattr = 6;
  network_ps_rqst_setattr = 16#0A;
  network_ps_rqst_pagin = 16#0C;
  network_ps_rqst_ring_info = 16#0E;
  network_ps_reply_echo = 1;            { }
  network_ps_reply_pagout = 5;          { }
  network_ps_reply_getattr = 7;         { }
  network_ps_reply_unknown = 9;
  network_ps_reply_setattr = 16#0B;     { }
  network_ps_reply_pagin = 16#0D;       { }
  network_ps_reply_ring_info = 16#0F;   { }

type
  { A mapped page as OS_$DATA_COPY's operands, for network_$phys_copy's
    two windows: the routine pushes the windows' addresses by value as
    OS_$DATA_COPY's `in' and `out' operands, the dereferenced pointers'
    addresses (as rip/send.pas's `route_data_p^'). }
  network_$data_ptr_t = ^os_$data_t;

  { The service record NETWORK_$SET_SERVICE builds in its frame for the
    port-0 driver, 0x88 bytes: a zero word and the service in the
    driver's encoding, the length passed with it 0x88, and nothing else
    of the frame addressed above it.  ext_service is the external
    service. }
  network_$service_rec_t = record
    w_00: integer;                        { 0x00 }
    ext_service: pinteger;                { 0x02 }
    rest: array[16#04..16#87] of char;    { 0x04..0x87 }
  end;

  { The port driver's service entries (net_io/net_io.ins.pas
    net_io_$driver_t, its univ_ptr fields detach at 0x1C and ioctl at
    0x24), called through the record: NETWORK_$LOAD (detach) and
    NETWORK_$SET_SERVICE (ioctl), both after the same pushes, the
    socket's address, a service record by address, a word by value, two
    slots.  `val_param' for the word (route/service.pas's
    route_$attach_proc_t, the same entry at 0x1C, has the shape).  The
    record `in univ integer32', as route_$attach_proc_t's: LOAD passes
    a zero from the code in a 4-byte cell, and an expression passed to a
    `univ' formal is extended to the formal's size (ref 5.3, "Univ"), so
    the formal is 4 bytes; NETWORK_$SET_SERVICE passes its 0x88-byte
    record, a variable, as it is; `in univ' goes by address (dpc gives a
    PC-relative `pea'); out4 a
    word: the 2 bytes NETWORK_$SET_SERVICE's frame leaves between the
    token and the value's copy.  The names are route_$set_service_fn_t's. }
  network_$service_proc_t = ^procedure(var socket: integer;
                                       in service_rec: univ integer32;
                                       request: integer;
                                       out out4: integer;
                                       out status_ret: status_$t);
                            options(val_param);

  { The head every request and reply begins with: network_$do_request
    reads the command's first word and the reply's, and the reply's
    status longword after it: the reply's op is the request's plus one.
    Both are passed on whole (`univ'), so the record is the head only.
    The field is op because `type' is reserved. }
  network_$msg_hdr_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
  end;

  { The page-out request NETWORK_$WRITE builds in its frame, 0x2A bytes
    (its length): op 4; the checksum; the caller's page request copied
    in (0x20 bytes at +0x06), its page number advanced (+0x0E =
    req.page_num); the flag; the version 8.  The 0x06..0x25 part is the
    page request. }
  network_$pagout_rqst_t = record
    op: integer;                          { 0x00 }
    chksum: integer32;                    { 0x02 }
    req: network_$page_request_t;         { 0x06 }
    flag: boolean;                        { 0x26 }
    reserved_27: char;                    { 0x27 }
    version: integer;                     { 0x28 }
  end;

  { The page-out reply, the 0xB8-byte buffer NETWORK_$WRITE passes
    network_$do_request (the most network_$wait_response copies).
    NETWORK_$WRITE reads the version (+0x2A), the DTM's low word
    (+0x2C), the clock (+0x2E), the DTM's high longword (+0x16), and the
    old replies' DTM bits (+0x1A).  uid and page_num are the server's
    (network/process_paging_request.pas); the rest reserved, by
    offset. }
  network_$pagout_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    reserved_06: integer32;               { 0x06 }
    uid: uid_$t;                          { 0x0A }
    page_num: linteger;                   { 0x12 }
    dtm_high: integer32;                  { 0x16 }
    dtm_bits: char;                       { 0x1A }
    reserved_1b: char;                    { 0x1B }
    reserved_1c: array[16#1C..16#29] of char;
                                          { 0x1C..0x29 }
    version: integer;                     { 0x2A }
    dtm_low: pinteger;                    { 0x2C }
    clock: time_$clock_t;                 { 0x2E }
    rest: array[16#34..16#B7] of char;    { 0x34..0xB7 }
  end;

  { The page-in request NETWORK_$READ_AHEAD builds in its frame, 0x2E
    bytes (its length): op 16#0C and version 8 in one longword store; the
    page size 16#400 (+0x2C); the limit (+0x04); the caller's page
    request copied in (+0x06), its page number set (+0x0E); the flags
    byte (+0x26); the count (+0x28); no_read_ahead (+0x2A).  flag_1a and
    flag_18 are the routine's parameter offsets, op for `type'; the words
    integer (the server reads limit and
    page_size signed, network/process_paging_request.pas). }
  network_$pagin_rqst_t = record
    op: integer;                          { 0x00 }
    version: integer;                     { 0x02 }
    limit: integer;                       { 0x04 }
    req: network_$page_request_t;         { 0x06 }
    flag_1a: boolean;                     { 0x26 }
    reserved_27: char;                    { 0x27 }
    count: integer;                       { 0x28 }
    flag_18: boolean;                     { 0x2A }
    reserved_2b: char;                    { 0x2B }
    page_size: integer;                   { 0x2C }
  end;

  { The page-in reply, the 0xB8-byte buffer NETWORK_$READ_AHEAD passes
    network_$wait_response (the data pages' array follows it).  It
    reads the op, the status (+0x02), the sequence number (+0x08), the
    version (+0x06), the page count (+0x0A), the page request, copied out
    whole (+0x0C), the checksum (+0x2C), the more word, by its sign
    (+0x30), and three clocks, each a longword and a word (+0x34 dtm,
    +0x3C clock, +0x44 acl, the words between them unread).  The clocks
    as records; op for `type', the rest reserved by offset. }
  network_$pagin_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    version: integer;                     { 0x06 }
    seq: integer;                         { 0x08 }
    page_cnt: integer;                    { 0x0A }
    req: network_$page_request_t;         { 0x0C }
    chksum: integer32;                    { 0x2C }
    more: integer;                        { 0x30 }
    reserved_32: integer;                 { 0x32 }
    dtm: time_$clock_t;                   { 0x34 }
    reserved_3a: integer;                 { 0x3A }
    clock: time_$clock_t;                 { 0x3C }
    reserved_42: integer;                 { 0x42 }
    acl: time_$clock_t;                   { 0x44 }
    rest: array[16#4A..16#B7] of char;    { 0x4A..0xB7 }
  end;

  { NETWORK_$READ_AHEAD's cursor into its page list, stepped by a
    longword. }
  network_$ppn_ptr_t = ^integer32;

  { The request buffer NETWORK_$AST_GET_INFO and NETWORK_$RING_INFO pass
    network_$do_request, 0x48 bytes in both frames: the reply buffer
    lies right below it, though AST_GET_INFO sends 0x32 bytes and
    RING_INFO 2; the server receives into a buffer of the same size
    (0x48 bytes).  AST_GET_INFO stores op 6; the UID (+0x02); the
    caller's flags word (+0x0A); the version 8 (+0x0C); the whole
    location record (+0x12); the four bytes at +0x0E are never written.
    RING_INFO stores op 16#0E only.  flags a word, as the client stores
    it; op for `type'; the rest by offset. }
  network_$ps_rqst_t = record
    op: integer;                          { 0x00 }
    case integer of
      1: (uid: uid_$t;                    { 0x02 }
          flags: integer;                 { 0x0A }
          version: integer;               { 0x0C }
          reserved_0e: integer32;         { 0x0E }
          loc: network_$obj_loc_t);       { 0x12..0x31 }
      2: (bytes: array[16#02..16#47] of char);
                                          { 0x02..0x47 }
  end;

  { The reply buffer NETWORK_$AST_GET_INFO and NETWORK_$RING_INFO pass
    network_$do_request, 0xB8 bytes in both frames (the most
    network_$wait_response copies; NETWORK_$WRITE's
    network_$pagout_reply_t the same size).  AST_GET_INFO's new reply,
    length 0xB8: the location record at +0x08, its node address written
    (+0x18), and the attribute record at +0x28; an old reply's 0x40-byte
    record at +0x06.  RING_INFO's token-ring record at +0x06.  The page
    server's old attribute reply ends with its version (+0x46, the reply
    0x48 bytes long): old_version.  op and status as
    network_$msg_hdr_t's. }
  network_$ps_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    case integer of
      1: (version: integer;               { 0x06 }
          loc: network_$obj_loc_t;        { 0x08 }
          attrs: network_$attr_rec_t);    { 0x28..0xB7 }
      2: (old_attrs: network_$old_attr_rec_t;
                                          { 0x06..0x45 }
          old_version: integer);          { 0x46 }
      3: (ring: network_$ring_info_t);    { 0x06..0x7F }
  end;

  { The message NETWORK_$REPORT_FAILURE sends, 0x18 bytes (its length,
    the template length's high word): the type 16#3000E, and the failure
    type; the 16 bytes after them are never written.  Not known: whether
    kind is one longword or two words, 3 and 16#0E, stored at once
    (NETWORK_$READ_AHEAD's op and version are). }
  network_$failure_msg_t = record
    kind: integer32;                      { 0x00 }
    failure_type: linteger;               { 0x04 }
    reserved_08: array[1..16] of char;    { 0x08..0x17 }
  end;

{ REM_FILE_$SOCK_LOCK is declared extern in rem_file/rem_file.ins.pas
  (included above); this block defines it (below). }


type
  { The received request's header record, at the address APP_$RECEIVE
    returns in app_$receive_rec_t's reply (app/app.ins.pas): the page
    server reads the request's length (compared unsigned, +0x02); the
    data length (+0x04), the request id (+0x06), a node and a socket
    (+0x08, +0x0C) and another (+0x0E, +0x12), copied as words and
    longwords; and the packet flags byte (+0x14).  node_a and sock_a
    become the reply's source, node_b and sock_b its destination. }
  network_$rcv_rec_t = record
    reserved_00: integer;                 { 0x00 }
    rqst_len: pinteger;                   { 0x02 }
    data_len: pinteger;                   { 0x04 }
    request_id: pinteger;                 { 0x06 }
    node_a: linteger;                     { 0x08 }
    sock_a: integer;                      { 0x0C }
    node_b: linteger;                     { 0x0E }
    sock_b: integer;                      { 0x12 }
    flags: pkt_$byte_t;                   { 0x14 }
  end;
  network_$rcv_rec_ptr_t = ^network_$rcv_rec_t;



{ NETWORK_$REPORT_FAILURE - record a transmit failure and announce it.
  Here, not in network/network.ins.pas, because its type is RING's
  (ring/ring_driver.ins.pas). }
procedure network_$report_failure(in xmit_status: ring_$csr_t); extern;


{ The module's own variables and the globals it defines (ref 7.2.2,
  7.3.4, Method 2), in the order of the block (above); then the
  routines in map order. }
var
  network_$server_pkt_info: pkt_$info_t := [
    flags := 16#0008, routing_type := pkt_$routing_inet,
    addr_type := pkt_$addr_long,
    protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
    field_0c := 16#FFFF];                          { +0x000 }
  network_$request_pkt_info: pkt_$info_t := [
    flags := 16#0008, routing_type := pkt_$routing_inet,
    addr_type := pkt_$addr_long,
    protocol := 16#8031, retry_limit := 16#0001, field_0a := 0,
    field_0c := 16#FFFF];                          { +0x020 }
  network_$net_table: array[1..64] of network_$net_entry_t;
                                                   { +0x040, zero }

define
  rem_file_$sock_lock;                             { +0x240, zero }

var
  { TODO(pascal) 6 bytes at +0x252 of the block nothing addresses

    +0x252..+0x257 lie between REM_FILE_$SOCK_LOCK (0x12 bytes from
    +0x240) and network_$rqst_done_ec (+0x258); no instruction
    addresses them.  dpc places the eventcount at the next longword,
    +0x254, without them (the probe, network/README.md).  The
    lead that objects of 8 bytes or more are 8-aligned from the block
    would put it at +0x258, and the 4 bytes after each eventcount
    (unused_264, unused_274; AREA_'s block has the same after each of
    its three, area/area.pas) are what it would leave before the next
    one; but this block breaks the lead elsewhere.  The
    stand-in holds the place. }
  unused_252: array[1..3] of integer;              { +0x252, zero }
  network_$rqst_done_ec: ec_$eventcount_t := [
    value := 0,
    waiter_list_head := addr(network_$rqst_done_ec),
    waiter_list_tail := addr(network_$rqst_done_ec)];
                                                   { +0x258 }
  unused_264: integer32;                           { +0x264, zero }
  network_$rqst_quit_ec: ec_$eventcount_t := [
    value := 0,
    waiter_list_head := addr(network_$rqst_quit_ec),
    waiter_list_tail := addr(network_$rqst_quit_ec)];
                                                   { +0x268 }
  unused_274: integer32;                           { +0x274, zero }
  network_$rqst_wait: array[1..4] of integer32;    { +0x278, zero }

  { TODO(pascal) 8 bytes at +0x288 of the block nothing addresses

    +0x288..+0x28F lie between network_$rqst_wait (16 bytes) and
    network_$page_wait (+0x290); no instruction of the NETWORK unit
    addresses them, nor any other reference.  A lead:
    NETWORK_$REQUEST_SERVER waits on five eventcounts with five values
    in its frame, the fifth a constant 1, after the four copied from the
    block; a declaration of five values (20 bytes) would end at +0x28C,
    and the 8-byte alignment lead would put the 16-byte
    network_$page_wait at +0x290.  But this block breaks that lead
    elsewhere (NETWORK_$FILE_BACKLOG at +0x2D4, NETWORK_$PAGING_FILE_UID
    at +0x314), so the stand-in holds the place. }
  unused_288: array[1..2] of integer32;            { +0x288, zero }
  network_$page_wait: array[1..4] of integer32;    { +0x290, zero }
  network_$zero_page_pa: integer32;                { +0x2A0, zero }
  network_$lock: integer32;                        { +0x2A4, zero }
  network_$ring_dcte: dcte_ptr_t;                  { +0x2A8, zero }

  { TODO(pascal) 4 bytes at +0x2AC of the block nothing addresses

    +0x2AC..+0x2AF lie between network_$ring_dcte and
    NETWORK_$PAGING_BACKLOG (+0x2B0, a map symbol); no instruction or
    other reference addresses them.  The 8-byte alignment lead (objects
    of 8 bytes or more 8-aligned from the block) would put the 36-byte
    backlog at +0x2B0, but the next backlog, also 36 bytes, follows it
    at +0x2D4, 4 mod 8. }
  unused_2ac: integer32;                           { +0x2AC, zero }

define
  network_$paging_backlog;                         { +0x2B0, zero }
  network_$file_backlog;                           { +0x2D4, zero }
  network_$failure_rec := [word0 := 2, flag := false, byte3 := chr(0),
                           node_id := 0, timestamp := 0,
                           failure_type := 0];     { +0x2F8 }
  network_$hdr_page_pa;                            { +0x308, zero }
  network_$hdr_page;                               { +0x30C, zero }
  network_$mother_node;                            { +0x310, zero }
  network_$paging_file_uid;                        { +0x314, zero }
  network_$service_time := 16#14;                  { +0x31C }

var
  network_$age_ticks: integer;                     { +0x31E, zero }

define
  network_$request_server_cnt;                     { +0x320, zero }
  network_$page_server_cnt;                        { +0x322 }
  network_$file_over_cnt;                          { +0x324 }
  network_$rev_2_info_rqst_retry;                  { +0x326 }
  network_$overflow_reply;                         { +0x328 }
  network_$rcv_read_ahead;                         { +0x32A }
  network_$mult_pagin_rqst_cnt;                    { +0x32C }
  network_$bad_chksum_cnt;                         { +0x32E }
  network_$read_viol_cnt;                          { +0x330 }
  network_$write_viol_cnt;                         { +0x332 }
  network_$read_call_cnt;                          { +0x334 }
  network_$write_call_cnt;                         { +0x336 }
  network_$set_attrib_call_cnt;                    { +0x338 }
  network_$attrib_rqst_cnt;                        { +0x33A }
  network_$info_rqst_cnt;                          { +0x33C }
  network_$pagin_rqst_cnt;                         { +0x33E }
  network_$pagout_rqst_cnt;                        { +0x340 }
  network_$allowed_service;                        { +0x342, zero }
  network_$activity_flag;                          { +0x346, zero }
  network_$loopback_flag;                          { +0x348 }
  network_$do_chksum;                              { +0x34A }
  network_$user_sock_open;                         { +0x34C }
  network_$really_diskless;                        { +0x34E }
  network_$diskless;                               { +0x350 }

var
  network_$retry_delay: time_$clock_t := [high := 0, low := 16#09C4];
                                                   { +0x354 }
  network_$request_send_flags: pinteger := 1;      { +0x35A }
  network_$report_send_flags: pinteger := 0;       { +0x35C }
  network_$reply_send_flags: pinteger := 0;        { +0x35E }

define
  network_$clear_wired;                            { +0x360, zero }

var
  network_$std_open_flag: boolean := true;         { +0x362, ff }

define
  network_$install_net;
  network_$remove_net;
  network_$get_net;
  get_chksum;
  network_$gethdr;
  network_$rtnhdr;
  network_$set_service;
  network_$get_pkt_size;
  network_$write;
  network_$read_ahead;
  network_$ast_get_info;
  network_$ring_info;
  network_$report_failure;
  network_$page_server;
  network_$request_server;
  network_$init;
  network_$load;
  network_$read_service;
  network_$add_page_servers;
  network_$add_request_servers;
  network_$dismiss_request_servers;

{ ---- WIRED_PROC ---- }
%include 'network/phys_copy.pas';           { network_$phys_copy }
%include 'network/install_net.pas';         { NETWORK_$INSTALL_NET }
%include 'network/remove_net.pas';          { NETWORK_$REMOVE_NET }
%include 'network/get_net.pas';             { NETWORK_$GET_NET }
%include 'network/page_chksum.pas';         { GET_CHKSUM }
%include 'network/gethdr.pas';              { NETWORK_$GETHDR }
%include 'network/rtnhdr.pas';              { NETWORK_$RTNHDR }
%include 'network/set_service.pas';         { NETWORK_$SET_SERVICE }
%include 'network/send_request.pas';        { network_$send_request }
%include 'network/wait_response.pas';       { network_$wait_response }
%include 'network/do_request.pas';          { network_$do_request }
%include 'network/get_pkt_size.pas';        { NETWORK_$GET_PKT_SIZE }
%include 'network/write.pas';               { NETWORK_$WRITE }
%include 'network/read_ahead.pas';          { NETWORK_$READ_AHEAD }
%include 'network/ast_get_info.pas';        { NETWORK_$AST_GET_INFO }
%include 'network/ring_info.pas';           { NETWORK_$RING_INFO }
%include 'network/report_failure.pas';      { NETWORK_$REPORT_FAILURE }
%include 'network/page_server.pas';         { NETWORK_$PAGE_SERVER, with
                                              its nested
                                              network_$ps_send_reply and
                                              network_$process_paging_
                                              request }
%include 'network/request_server.pas';      { NETWORK_$REQUEST_SERVER }

{ ---- OS_INIT_PROC ---- }
%include 'network/init.pas';                { NETWORK_$INIT }
%include 'network/load.pas';                { NETWORK_$LOAD }

{ ---- PROCEDURE$ ---- }
%include 'network/read_service.pas';        { NETWORK_$READ_SERVICE }
%include 'network/add_page_servers.pas';    { NETWORK_$ADD_PAGE_SERVERS }
%include 'network/add_request_servers.pas'; { NETWORK_$ADD_REQUEST_SERVERS }
%include 'network/dismiss_request_servers.pas';
                                            { NETWORK_$DISMISS_REQUEST_
                                              SERVERS }
