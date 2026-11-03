{ NETWORK_$READ_AHEAD - page a run of pages in from a remote node.

  Image addresses:
    sau2  0x00E0FC08  NETWORK_$READ_AHEAD
    sau8  0x03C10F38  NETWORK_$READ_AHEAD

  - Page-in requests (op 16#0C, version 8) for count pages from
    req.page_num go to the node, on a socket of its own; the replies'
    pages go into physical pages whose numbers go to ppn_array.
  - Each request asks for at most 32 pages (8 across a router).  A
    timeout resends (forever for the mother node); a bad length or
    checksum retries up to the send's retry count.
  - The first good reply gives the status, the clocks and the request
    record back.  End of object or "page null" zero-fills.  The result
    is the pages delivered.
  - The routine goes on after the CRASH_SYSTEM calls; in the delivery
    loop the loop then runs again.
  - get_chksum is passed data_len; dtm.high is cleared also when the
    call fails; a partial last page goes back to NETBUF uncounted.

  Status stored:
    status_$ok: the pages were delivered (also at end of object)
    the first reply's status: a reply's own failure
    status_$network_request_denied_by_local_node: paging not allowed
    status_$network_remote_node_failed_to_respond: no reply
    status_$network_data_length_too_large: a reply's data too long
    status_$network_too_many_transmit_retries: the retries spent
    status_$network_unexpected_reply_type: another reply
    the callees' statuses: a send failed
}

{ TODO(pascal) NETWORK_$READ_AHEAD's frame temporaries

  The frame has 0x174 bytes.  Below the locals the image keeps, in
  frame cells, the widened count (written with end_pg, read in each
  request's donation count), addr(sock_$socket_ptr[sock]) + 4,
  page_size and limit widened, and a widened word as a subtraction's
  memory operand (done, then data_len, read after the delivery loop;
  partial in the zero-fill loop).  dpc hoists no invariants and keeps
  no such temporaries.  Not addressed: -0x128 (4), -0x136
  (2), -0x13e..-0x142 (6), -0x146 (2), -0x156..-0x159 (4),
  -0x15c..-0x15f (4). }

{ TODO(pascal) NETWORK_$READ_AHEAD's donated count

  The donation loop compares need with donated as signed words: both
  integer (an integer against a pinteger widens both to longwords here,
  as retries against retry_max).  But the end's `for i := 1 to donated'
  has the unsigned count's guard, a test for zero and the decrement
  with no sign branch, which
  an integer bound does not give.  donated is written integer; the
  guard is not explained. }

function network_$read_ahead(in node_addr: uid_$t;
                             in out req: network_$page_request_t;
                             out ppn_array: univ network_$ppn_list_t;
                             page_size: pinteger; count: integer;
                             no_read_ahead: boolean; flags: boolean;
                             out dtm: time_$clock_t;
                             out clock: time_$clock_t;
                             out acl_info: time_$clock_t;
                             out status: status_$t): integer;
label
  10, 20, 30, 40, 90;
var
  data_bufs: pkt_$data_pages_t;
  reply: network_$pagin_reply_t;
  request: network_$pagin_rqst_t;
  chksum: integer32;
  calloc_ppn: integer32;
  dat: integer32;
  src: integer32;
  st: status_$t;
  end_pg: linteger;
  start: linteger;
  ec_value: integer32;
  donated: integer;
  zero_len: integer;
  bufs_used: integer;
  seq: integer;
  timeout: pinteger;
  retry_max: pinteger;
  limit: integer;
  data_len: pinteger;
  resp_len: integer;
  pkt_id: integer;
  sock: pinteger;
  hdr_done: boolean;
  remain: integer32;
  chunk: integer;
  need: integer;
  zero_bytes: integer32;
  i: integer;
  partial: integer;
  dst: integer32;
  done: integer;
  retries: integer;
  cursor: network_$ppn_ptr_t;
begin
  dtm.high := 0;
  if not (network_service_paging in network_$allowed_service.service)
  then begin
    status.all := status_$network_request_denied_by_local_node;
    network_$read_ahead := 0;
    return;
  end;

  if not sock_$allocate(sock, 16#20, 0, 0, 1024) then
    crash_system(status_$network_receive_process_failed_to_start);

  donated := 0;
  done := 0;
  hdr_done := false;
  partial := 0;
  if (node_addr.high = 0) or else (node_addr.high = network_$me) then
    limit := 32
  else
    limit := 8;
  request.req := req;
  start := req.page_num;
  end_pg := start + count;
  cursor := addr(ppn_array);

  while start < end_pg do begin
    { the request }
    pkt_id := pkt_$next_id;
    request.op := network_ps_rqst_pagin;
    request.version := 8;
    request.page_size := 1024;
    request.limit := limit;
    request.req.page_num := start;
    request.flag_1a := flags;
    request.count := end_pg - start;
    request.flag_18 := no_read_ahead;
    seq := 1;

    { donate the buffers the reply may need }
    retries := 0;
    need := max(min(((end_pg - start) * 1024 + page_size - 1) div
                    page_size, limit) - (count - done), 0);
    while need > donated do begin
      wp_$calloc(calloc_ppn, st);
      netbuf_$rtn_dat(lshft(calloc_ppn, 10));
      donated := donated + 1;
    end;

  10:
    { resend }
    ec_value := sock_$socket_ptr[sock]^.ec.value + 1;
    network_$send_request(node_addr, sock, pkt_id, request, 16#2E, 0, 0,
                          retry_max, timeout, st);
    if st.all <> status_$ok then
      goto 90;

  20:
    { wait }
    if start >= end_pg then
      goto 90;
    if not network_$wait_response(sock, pkt_id,
                                  timeout + network_$service_time,
                                  ec_value, reply, resp_len, data_bufs,
                                  data_len) then begin
      retries := retries + 1;
      if done > 0 then
        goto 90;
      if (retries > retry_max) and then
         (node_addr.low <> network_$mother_node) then begin
        st.all := status_$network_remote_node_failed_to_respond;
        goto 90;
      end;
      if seq > 1 then
        next;
      goto 10;
    end;

    { the data whole kilobytes }
    bufs_used := 0;
    remain := data_len;
    if (data_len & 16#3FF) <> 0 then begin
      pkt_$dump_data(data_bufs, data_len);
      retries := retries + 1;
      if retries <= retry_max then
        goto 10;
      st.all := status_$network_data_length_too_large;
      goto 90;
    end;

    { the reply, and its checksum }
    if (reply.op <> network_ps_reply_pagin) or else (reply.seq <> seq) then
      goto 40;
    st := reply.status;
    if (reply.chksum <> 0) and then network_$do_chksum and then
       ((st.all = status_$ok) or else
        (st.all = status_$pmap_page_null)) then begin
      chksum := get_chksum(data_bufs[1], data_len);
      if chksum <> reply.chksum then begin
        crash_system(status_$network_bad_checksum);
        pkt_$dump_data(data_bufs, data_len);
        data_bufs[1] := 0;
        network_$bad_chksum_cnt := network_$bad_chksum_cnt + 1;
        retries := retries + 1;
        if retries <= retry_max then
          goto 10;
        st.all := status_$network_too_many_transmit_retries;
      end;
    end;

    { the first reply's outputs }
    if not hdr_done then begin
      status := st;
      if reply.version >= 7 then begin
        clock := reply.clock;
        acl_info := reply.acl;
        dtm := reply.dtm;
      end;
      req := reply.req;
      hdr_done := true;
    end;

    if (remain > 1024) and then (remain mod 1024 <> 0) then
      crash_system(status_$network_receive_process_failed_to_start);
    if (st.all <> status_$ok) and then
       ((st.all <> status_$pmap_page_null) or else
        (reply.version <> 1)) then
      goto 30;

    { deliver the data pages }
    while remain > 0 do begin
      if partial = 0 then begin
        bufs_used := bufs_used + 1;
        dst := data_bufs[bufs_used];
        cursor^ := rshft(dst, 10);
        if remain >= 1024 then begin
          done := done + 1;
          cursor := network_$ppn_ptr_t(integer32(cursor) + 4);
          remain := remain - 1024;
        end
        else begin
          partial := remain;
          dst := dst + remain;
          remain := 0;
        end;
      end
      else if 1024 - partial < remain then
        crash_system(status_$network_receive_process_failed_to_start)
      else begin
        bufs_used := bufs_used + 1;
        src := data_bufs[bufs_used];
        network_$phys_copy(dst, src, remain);
        netbuf_$rtn_dat(src);
        partial := partial + remain;
        if partial < 1024 then
          dst := dst + remain
        else begin
          partial := 0;
          done := done + 1;
          cursor := network_$ppn_ptr_t(integer32(cursor) + 4);
        end;
        remain := 0;
      end;
    end;

    seq := seq + 1;
    start := start + data_len div 1024;
    if seq <= reply.page_cnt then
      goto 20;
    if (reply.more >= 0) or else (done <= 0) then
      next;
    goto 90;

  30:
    { error_status }
    if st.all <> status_$pmap_page_null then begin
      if not ((st.all = status_$ast_eof) and not flags) then
        goto 90;
      if partial <= 0 then
        goto 90;
    end;

    { zero the rest of the partial page }
    if st.all = status_$ast_eof then begin
      zero_len := 1024 - partial;
      network_$phys_copy(dst, network_$zero_page_pa, zero_len);
      partial := 0;
      done := done + 1;
      st.all := status_$ok;
      goto 90;
    end;

    { nothing yet, the pages null }
    if (done = 0) and then (partial = 0) and then
       (reply.page_cnt > 0) then begin
      cursor := addr(ppn_array);
      cursor^ := 0;
      done := reply.page_cnt;
      goto 90;
    end;

    { zero-fill page_cnt pages }
    zero_bytes := reply.page_cnt * 1024;
    while zero_bytes > 0 do begin
      chunk := min(1024 - partial, zero_bytes);
      if partial = 0 then begin
        if (chunk < 1024) and then (done > 0) then
          goto 90;
        netbuf_$get_dat(dat);
        dst := dat;
        cursor^ := rshft(dst, 10);
      end;
      network_$phys_copy(dst, network_$zero_page_pa, chunk);
      partial := partial + chunk;
      if partial < 1024 then
        dst := dst + chunk
      else begin
        partial := 0;
        done := done + 1;
        cursor := network_$ppn_ptr_t(integer32(cursor) + 4);
      end;
      start := start + chunk div 1024;
      zero_bytes := zero_bytes - chunk;
    end;
    next;

  40:
    { wrong_reply }
    if data_bufs[1] <> 0 then
      pkt_$dump_data(data_bufs, data_len);
    if reply.op = network_ps_reply_pagin then
      goto 20;
    st.all := status_$network_unexpected_reply_type;
    if seq = 1 then
      goto 90;
  end;

90:
  { take the donated buffers back }
  for i := 1 to donated do begin
    netbuf_$get_dat(dat);
    mmap_$free(rshft(dat, 10));
  end;

  if partial <> 0 then
    netbuf_$rtn_dat(lshft(ppn_array[done], 10));
  sock_$close(sock);
  network_$read_call_cnt := network_$read_call_cnt + done;
  if done > 1 then
    network_$rcv_read_ahead := network_$rcv_read_ahead + done - 1;
  if (not hdr_done) or else (done = 0) then
    status := st;
  network_$read_ahead := done;
end;
