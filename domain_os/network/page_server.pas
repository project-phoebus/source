{ NETWORK_$PAGE_SERVER - the body of a network page server process.

  Image addresses:
    sau2  0x00E11548  NETWORK_$PAGE_SERVER
    sau8  0x03C1281E  NETWORK_$PAGE_SERVER
    sau9  0x3C413932  NETWORK_$PAGE_SERVER
    sau2  0x00E10510  network_$ps_send_reply (nested)
    sau8  0x03C11824  network_$ps_send_reply (nested)
    sau9  0x3C412938  network_$ps_send_reply (nested)
    sau2  0x00E10628  network_$process_paging_request (nested)
    sau8  0x03C1193C  network_$process_paging_request (nested)
    sau9  0x3C412A50  network_$process_paging_request (nested)

  - Start-up: the remote page pool grows by 34 pages, a zero page is
    taken, sockets 1 (paging) and 6 (overflow) are opened, the four wait
    values set, and the server lock taken.
  - Then forever it waits for socket 6 (a request refused), socket 1
    (network_$process_paging_request), NETLOG_$EC (NETLOG_$SEND_PAGE) or
    the clock (a ring polled for a sticky biphase error).
  - Every fifth biphase error in a row is reported as a transmit
    failure (NETWORK_$REPORT_FAILURE).
  - After each, the first later slot whose eventcount has already
    reached its value is served.
  - A failed WP_$CALLOC crashes the system after NETWORK_$ZERO_PAGE_PA
    is set.
  - The overflow reply's first four bytes are FFFF FFFF over the request
    bytes copied there.

  Status stored: none.
}

{ TODO(pascal) the 0x1E-byte copy of NETWORK_$SERVER_PKT_INFO

  As in NETWORK_$REPORT_FAILURE (network/report_failure.pas's TODO): the
  packet info is copied as seven longwords and a word, 30 bytes, into a
  pkt_$info_t of 32.  Not settled. }

{ TODO(pascal) PAGE_SERVER's frame stand-ins

  The regions of the shared frame no instruction addresses: -0x4 (4
  bytes), -0x30E (10), -0x316 (2), -0x31E (2), -0x32A (6), -0x338 (8),
  -0x356 (2), -0x35E (6), -0x36C (6) and -0x384 (10).  The register-held slot,
  sticky, i and rcv would have had slots; which, is not known:
  here they fill the last region, whose 10 bytes they take exactly.  A
  region of 8 bytes or more that does not start at a multiple of 8 from
  A6 is held by smaller stand-ins (-0x30E by two longwords and a word),
  since an object of 8 bytes or more is placed at such a multiple. }

procedure network_$page_server;
label
  10, 20;
type
  { The page server's packet flags as a set (pkt/pkt.ins.pas pkt_$info_t
    flags, a pinteger): network_$process_paging_request tests member 2
    (four places): the request is refused. }
  network_$ps_flag_set_t = set of 0..15;

  { The attribute-setting request:
    network_$process_paging_request reads the version (+0x02), and hands
    AST_$SET_ATTRIBUTE the UID (+0x04), the attribute word (+0x0C), and
    the value (+0x0E); the value's 0x34 bytes to 0x41, inside the
    0x48-byte buffer. }
  network_$ps_setattr_rqst_t = record
    op: integer;                          { 0x00 }
    version: integer;                     { 0x02 }
    uid: uid_$t;                          { 0x04 }
    attr_id: integer;                     { 0x0C }
    value: file_$attr_value_t;            { 0x0E..0x41 }
  end;

  { The attribute request as the server reads it: network_$ps_rqst_t's
    fields (its variant 1, the client's), with the byte at +0x0B read as
    a boolean, tested by its sign (the client's flags word's low byte). }
  network_$ps_getattr_rqst_t = record
    op: integer;                          { 0x00 }
    uid: uid_$t;                          { 0x02 }
    reserved_0a: char;                    { 0x0A }
    big: boolean;                         { 0x0B }
    version: integer;                     { 0x0C }
    reserved_0e: integer32;               { 0x0E }
    loc: network_$obj_loc_t;              { 0x12..0x31 }
  end;

  { The attribute request's UID's low longword as the server tests it:
    bits 27..20 read as a packed field and masked with 16#E0, and bits
    27..25 of the reply's copy cleared; the bits are named by
    position. }
  network_$ps_uid_low_t = packed record
    case integer of
      1: (bits_31_28: 0..15;
          bits_27_20: 0..255;
          bits_19_0: 0..16#FFFFF);
      2: (bits_31_28_b: 0..15;
          bits_27_25: 0..7;
          bits_24_0: 0..16#1FFFFFF);
  end;

  { The request buffer, 0x48 bytes: the op, then one view per request,
    and the attribute request's UID low longword's bits. }
  network_$ps_rqst_buf_t = record
    case integer of
      1: (ps: network_$ps_rqst_t);
      2: (pagin: network_$pagin_rqst_t);
      3: (pagout: network_$pagout_rqst_t);
      4: (setattr: network_$ps_setattr_rqst_t);
      5: (getattr: network_$ps_getattr_rqst_t);
      6: (uid_bits: record
                      reserved_00: array[16#00..16#05] of char;
                                          { 0x00..0x05 }
                      uid_low: network_$ps_uid_low_t;
                                          { 0x06: getattr.uid.low }
                    end);
  end;

  { The page-out reply as the server builds it (NETWORK_$WRITE's
    network_$pagout_reply_t, the client's view): the request's page
    request copied in whole at +0x0A, then the DTM's high longword over
    its +0x0C (+0x16), the DTM bits (+0x1A), two longwords cleared
    (+0x1C, +0x20), the version 8 (+0x2A), the DTM's low word (+0x2C),
    and the clock, to TIME_$CLOCK (+0x2E).  reserved_ by offset. }
  network_$ps_pagout_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    reserved_06: integer32;               { 0x06 }
    case integer of
      1: (req: network_$page_request_t);  { 0x0A..0x29 }
      2: (reserved_0a: array[16#0A..16#15] of char;
                                          { 0x0A..0x15 }
          dtm_high: integer32;            { 0x16 }
          dtm_bits: pkt_$byte_t;          { 0x1A }
          reserved_1b: char;              { 0x1B }
          zero_1c: integer32;             { 0x1C }
          zero_20: integer32;             { 0x20 }
          reserved_24: array[16#24..16#29] of char;
                                          { 0x24..0x29 }
          version: integer;               { 0x2A }
          dtm_low: pinteger;              { 0x2C }
          clock: time_$clock_t);          { 0x2E..0x33 }
  end;

  { The attribute-setting reply, 0x0E bytes (its length): the version 8
    (+0x06), the DTM's high longword and low word (+0x08, +0x0C). }
  network_$ps_setattr_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    version: integer;                     { 0x06 }
    dtm_high: integer32;                  { 0x08 }
    dtm_low: pinteger;                    { 0x0C }
  end;

  { The token-ring reply, 0x80 bytes (its length), the record
    NETWORK_$RING_INFO copies out of it from +0x06 (network/network.ins.pas
    network_$ring_info_t, 0x7A bytes): a word 3 (+0x06),
    NETWORK_$DISKLESS (+0x08) and NETWORK_$MOTHER_NODE (+0x0A),
    RING_$DATA[0] whole (+0x0E, 15 longwords), NETWORK_$FAILURE_REC
    (+0x4A, 4 longwords), RING_$SWDIAG_DATA whole (+0x5A, 7 longwords and
    a word), then RING_$SWDIAG_RCVCNT and RING_$SWDIAG_NODEID over the
    diagnostic record's +0x02 and +0x1A, and the four biphase and ESB
    words (+0x78..+0x7E). }
  network_$ps_ring_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    kind_00: integer;                     { 0x06 }
    diskless: boolean;                    { 0x08 }
    reserved_09: char;                    { 0x09 }
    mother_node: integer32;               { 0x0A }
    stats: ring_$stats_t;                 { 0x0E..0x49 }
    failure_rec: network_$failure_rec_t;  { 0x4A..0x59 }
    case integer of
      1: (swdiag: ring_$swdiag_t;         { 0x5A..0x77 }
          xmit_biphase: pinteger;         { 0x78 }
          rcv_biphase: pinteger;          { 0x7A }
          xmit_esb: pinteger;             { 0x7C }
          rcv_esb: pinteger);             { 0x7E }
      2: (swdiag_00: integer;             { 0x5A }
          swdiag_rcvcnt: integer32;       { 0x5C }
          swdiag_06: array[16#60..16#73] of char;
                                          { 0x60..0x73 }
          swdiag_nodeid: integer32);      { 0x74..0x77 }
  end;

  { The old attribute reply's record (+0x06, network_$ps_reply_t's
    old_attrs) as the server fills it for an object it does not keep:
    the kind byte 3 (+0x07), the UID twice (+0x0A, +0x1A), the size
    16#400 (+0x22).  reserved_ by offset. }
  network_$ps_old_reply_t = record
    op: integer;                          { 0x00 }
    status: status_$t;                    { 0x02 }
    reserved_06: char;                    { 0x06 }
    kind: pkt_$byte_t;                    { 0x07 }
    reserved_08: integer;                 { 0x08 }
    uid: uid_$t;                          { 0x0A }
    reserved_12: array[16#12..16#19] of char;
                                          { 0x12..0x19 }
    uid2: uid_$t;                         { 0x1A }
    size: integer32;                      { 0x22 }
  end;

  { The reply buffer, 0xB8 bytes: one view per reply, and its words (the
    overflow reply's FFFF FFFF, two word stores); the location and
    attribute records as AST_$GET_ATTRIBUTES takes them (+0x08, +0x28),
    file/file.ins.pas's types (a type transfer is a function, not a
    variable: ref 4-197); and the location's UID low longword's bits. }
  network_$ps_reply_buf_t = record
    case integer of
      1: (ps: network_$ps_reply_t);
      2: (pagin: network_$pagin_reply_t);
      3: (pagout: network_$ps_pagout_reply_t);
      4: (setattr: network_$ps_setattr_reply_t);
      5: (ring: network_$ps_ring_reply_t);
      6: (old: network_$ps_old_reply_t);
      7: (words: array[0..91] of integer);
      8: (floc: record
                  reserved_00: array[16#00..16#07] of char;
                                          { 0x00..0x07 }
                  loc: file_$obj_loc_t;   { 0x08..0x27 }
                  attrs: file_$attributes_t;
                                          { 0x28..0xB7 }
                end);
      9: (loc_bits: record
                      reserved_00: array[16#00..16#13] of char;
                                          { 0x00..0x13 }
                      uid_low: network_$ps_uid_low_t;
                                          { 0x14: ps.loc.uid.low }
                    end);
  end;
var
  unused_4: integer32;                    { stand-in }
  rec: app_$receive_rec_t;
  pkt_info: pkt_$info_t;
  waits: array[0..3] of integer32;
  ecs: array[0..3] of ec_$eventcount_ptr_t;

  ppns: ast_$ppn_list_t;
  old_attrs: network_$old_attr_rec_t;
  reply: network_$ps_reply_buf_t;
  rqst: network_$ps_rqst_buf_t;
  data_pages: pkt_$data_pages_t;
  overflow_rqst: network_$ps_reply_buf_t;
  rtn_hdr_va: integer32;
  copy_dst_pa: integer32;
  copy_src_pa: integer32;
  unused_308: integer32;                  { stand-in }
  unused_30c: integer32;
  unused_30e: integer;
  end_clock: time_$clock_t;
  unused_316: integer;                    { stand-in }
  start_clock: time_$clock_t;
  unused_31e: integer;                    { stand-in }
  arrival: time_$clock_t;
  unused_32a: array[1..3] of integer;     { stand-in }
  deadline: time_$clock_t;
  unused_338: array[1..2] of integer32;   { stand-in }
  status: status_$t;
  zero_ppn: integer32;
  hdr_pa: integer32;
  routing_key: integer32;
  dest_node: linteger;
  src_node_or: integer32;
  src_node: linteger;
  unused_356: integer;                    { stand-in }
  token: pinteger;
  unused_35e: array[1..3] of integer;     { stand-in }
  failure_word: ring_$csr_t;
  touched: integer;
  log_page: integer;
  log_seg: integer;
  unused_36c: array[1..3] of integer;     { stand-in }
  pkt_flags: pinteger;
  src_sock: integer;
  data_len: pinteger;
  rqst_copy_len: pinteger;
  request_id: pinteger;
  dest_sock: integer;
  reply_len: pinteger;
  slot: integer;
  sticky: pinteger;
  i: integer;
  rcv: network_$rcv_rec_ptr_t;

%include 'network/ps_send_reply.pas';       { network_$ps_send_reply }
%include 'network/process_paging_request.pas';
                                            { network_$process_paging_request }

begin
  pkt_info := network_$server_pkt_info;

  token := ml_$spin_lock(network_$lock);
  mmap_$min_rmt_pool := mmap_$min_rmt_pool + 34;
  mmap_$pageable_pages_lower_limit := mmap_$min_rmt_pool;
  ml_$spin_unlock(network_$lock, token);

  if (mmap_$rmt_limit < 0) and then
     (network_$allowed_service.remote_pool < mmap_$min_rmt_pool) then
    network_$allowed_service.remote_pool :=
      mmap_$remote_pool(mmap_$min_rmt_pool);

  wp_$calloc(zero_ppn, status);
  network_$zero_page_pa := lshft(zero_ppn, 10);
  if status.all <> status_$ok then
    crash_system(status);
  ast_$page_zero(zero_ppn);

  discard(sock_$open(1, 16#10, 1, 8, 16#400));
  discard(sock_$open(6, 8, 0, 0, 16#400));

  token := ml_$spin_lock(network_$lock);
  waits[0] := network_$page_wait[1];
  network_$page_wait[1] := network_$page_wait[1] + 1;
  waits[1] := network_$page_wait[2];
  network_$page_wait[2] := network_$page_wait[2] + 1;
  waits[2] := network_$page_wait[3];
  network_$page_wait[3] := network_$page_wait[3] + 1;
  waits[3] := network_$page_wait[4];
  if network_$page_wait[4] < time_$clockh_ec.value then
    network_$page_wait[4] := time_$clockh_ec.value + 4
  else
    network_$page_wait[4] := network_$page_wait[4] + 4;
  ml_$spin_unlock(network_$lock, token);

  ecs[0] := addr(sock_$socket_ptr[6]^.ec);
  ecs[1] := addr(sock_$socket_ptr[1]^.ec);
  ecs[2] := addr(netlog_$ec);
  ecs[3] := addr(time_$clockh_ec);
  sticky := 0;
  proc1_$set_lock(ml_$server_lock);

10:
  slot := ec_$waitn(ecs, waits, 4) - 1;

20:
  data_pages[1] := 0;
  case slot of
    0: begin
      app_$receive(6, rec, status);
      if status.all = status_$ok then begin
        src_node_or := rec.hdr_f06;
        routing_key := rec.hdr_f12;
        rcv := network_$rcv_rec_ptr_t(rec.reply);
        data_len := rcv^.data_len;
        src_node := rcv^.node_a;
        src_sock := rcv^.sock_a;
        dest_node := rcv^.node_b;
        dest_sock := rcv^.sock_b;
        pkt_flags := rcv^.flags;
        request_id := rcv^.request_id;
        rqst_copy_len := min(4, rcv^.rqst_len);
        os_$data_copy(network_$data_ptr_t(rec.data)^, overflow_rqst,
                      rqst_copy_len);
        rtn_hdr_va := rec.data & (-16#400);
        netbuf_$rtn_hdr(rtn_hdr_va);
        if rec.data_pages[1] <> 0 then
          pkt_$dump_data(rec.data_pages, data_len);
        overflow_rqst.words[0] := -1;
        overflow_rqst.words[1] := -1;
        reply := overflow_rqst;
        reply_len := 4;
        data_pages[1] := 0;
        data_len := 0;
        network_$ps_send_reply;
        network_$file_over_cnt := network_$file_over_cnt + 1;
      end;
    end;
    1: begin
      network_$process_paging_request;
    end;
    2: begin
      netlog_$send_page;
    end;
    3: begin
      if network_$ring_dcte <> nil then begin
     if ring_$poll_sticky_bpherr(network_$ring_dcte) then begin
       sticky := (sticky + 1) mod 5;
       if sticky = 0 then begin
         failure_word := [ring_sendp_res_biphase];
         network_$report_failure(failure_word);
       end;
     end
     else
       sticky := 0;
   end;
    end;
  end;

  token := ml_$spin_lock(network_$lock);
  waits[slot] := network_$page_wait[slot + 1];
  if slot = 3 then begin
    if network_$page_wait[4] < time_$clockh_ec.value then
      network_$page_wait[4] := time_$clockh_ec.value + 4
    else
      network_$page_wait[4] := network_$page_wait[4] + 4;
  end
  else
    network_$page_wait[slot + 1] := network_$page_wait[slot + 1] + 1;
  ml_$spin_unlock(network_$lock, token);

  for i := slot + 1 to 3 do
    if ec_$read(ecs[i]^) - waits[i] >= 0 then begin
      slot := i;
      goto 20;
    end;
  goto 10;
end;
