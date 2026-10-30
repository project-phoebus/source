{ network_$process_paging_request - serve one request from the paging
  socket.

  Image addresses:
    sau2  0x00E10628  network_$process_paging_request (nested)
    sau9  0x3C412A50  network_$process_paging_request (nested)

  - The next packet is taken off socket 1 (an empty queue or a failure
    ends it), and at most 50 bytes of the request copied.  Then by the
    request's op:
  - 16#0C page-in: the pages are touched and wired, reply 16#0D sent,
    then the pages a packet at a time (the zero page for pages not on
    disk); log kind 1.
  - 4 page-out: the page's checksum is checked and the page given to the
    object (or a part page copied into it); reply 5, log kind 2.
  - 16#0A set attribute: AST_$SET_ATTRIBUTE; reply 16#0B unless it is
    too late, log kind 3.  0 echo: reply 1, the request itself.
  - 16#0E ring information: reply 16#0F, the ring's counters.  6
    attributes: reply 7, in the old format for a version below 5; log
    kind 4.  Any other op: reply 9.
  - Nested in NETWORK_$PAGE_SERVER, which includes this fragment.
  - The page-in send loops stop on st; a checksum mismatch goes on after
    CRASH_SYSTEM.
  - GET_CHKSUM is passed data_len; AREA_$TOUCH returns holding the PMAP
    lock; the attribute reply's log does not depend on its status.

  Status stored (in the reply):
    status_$ok: an attributes or ring information request
    the callees' statuses: a page-in, page-out or set attribute request
    status_$network_request_denied_by_remote_node: a page-in or
      attributes request the server refuses
    file_$object_not_found: an attributes request for an object it does
      not keep
    status_$network_unknown_request_type: any other op
}

{ TODO(pascal) the zero dividend in the page-in's packet count

  The packet count's subtrahend is an unsigned division (M$DIU$LLW) of
  a constant 0 by data_len, always 0: a division the source wrote with
  a dividend the compiler took as the constant 0 (a named constant, or
  an expression it folded, is not known).  The Pascal writes `0 div
  data_len'. }

{ TODO(pascal) the log's divisions

  queue and serve times are a longword difference divided by 250 as a
  word divide: a word quotient, and on overflow the dividend's low word
  left in place.  `integer32(..) div 250' is the longword division. }

{ TODO(pascal) network_$process_paging_request's frame stand-ins

  No instruction addresses -0x8, -0xc8, -0xd0, -0xdc, -0xe4,
  -0x104..-0xeb, -0x105 or -0x108..-0x107 (-0x4 is the static link's
  slot); the register-held variables (rcv, aste, ppp, depth, npkts,
  seq, k, i, anon) would have had slots there, 22 bytes of the
  49 (dpc gives each local an even offset, so old_flag's neighbor byte
  -0x105 is its pad).  Which ones are where is not known: here they
  fill the holes in declaration order, with the stand-ins unused_ for
  the rest, so that dpc --dump-locals gives the image's offsets and its
  0x108.  The 14 bytes at -0x104 are two stand-ins (10 bytes and a
  longword): one object of 8 bytes or more there would be placed at a
  multiple of 8 from A6. }

  procedure network_$process_paging_request;
  type
    { The log word NETLOG_$LOG_IT is handed as two words (arguments 5
      and 6): the log kind in its top byte (1, 2, 3, 4), the socket
      queue's depth in bits 23..20 and the requesting node in bits
      19..0, merged unmasked into the whole longword. }
    network_$ps_log_word_t = record
      case integer of
        1: (bits: packed record
                    kind: pkt_$byte_t;    { bits 31..24 }
                    depth: 0..15;         { bits 23..20 }
                    node: 0..16#FFFFF;    { bits 19..0 }
                  end);
        2: (all: linteger);
        3: (high: pinteger;               { 0x00 }
            low: pinteger);               { 0x02 }
    end;

    { A page request with its UID's low longword read as an area handle:
      the anonymous object's area id is its low word, passed to
      AREA_$ASSOC, and AREA_$TOUCH is handed its address. }
    network_$ps_req_t = record
      case integer of
        1: (pr: network_$page_request_t); { 0x00..0x1F }
        2: (uid_high: integer32;          { 0x00 }
            area: area_$handle_t);        { 0x04 }
    end;
  var
    rcv: network_$rcv_rec_ptr_t;
    pkt_addr: uid_$t;
    req: network_$ps_req_t;
    attrs: file_$attributes_t;
    rcv_st: status_$t;
    aste: ast_$aste_ptr_t;
    st: status_$t;
    unused_d0: integer32;                 { stand-in, see the TODO }
    new_ppn: integer32;
    st2: status_$t;
    unused_dc: integer32;                 { stand-in }
    log: network_$ps_log_word_t;
    unused_e4: integer32;                 { stand-in }
    attr_flags: integer;
    touch_flags: pinteger;
    touch_count: pinteger;
    ppp: integer;
    depth: pinteger;
    npkts: integer;
    seq: integer;
    k: integer;
    i: integer;
    unused_100: array[1..5] of integer;   { stand-in }
    unused_104: integer32;
    old_flag: boolean;
    anon: boolean;
  begin
    data_pages[1] := 0;
    app_$receive(1, rec, rcv_st);
    if (rcv_st.all = status_$network_buffer_queue_is_empty) or else
       (rcv_st.all <> status_$ok) then
      return;

    data_pages := rec.data_pages;
    if netlog_$ok_to_log_server then
      time_$abs_clock(start_clock);
    arrival.high := rec.src_addr;
    arrival.low := rec.src_port;

    log.bits.depth := rec.queue_count;
    rcv := network_$rcv_rec_ptr_t(rec.reply);
    log.all := (log.all & (-16#100000)) ! rcv^.node_b;

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
    rqst_copy_len := min(50, rcv^.rqst_len);

    os_$data_copy(network_$data_ptr_t(rec.data)^, rqst, rqst_copy_len);
    rtn_hdr_va := rec.data & (-16#400);
    netbuf_$rtn_hdr(rtn_hdr_va);

    depth := sock_$socket_ptr[1]^.queue_count;
    if depth <= 8 then
      network_$paging_backlog[depth] := network_$paging_backlog[depth] + 1
    else
      network_$paging_backlog[8] := network_$paging_backlog[8] + 1;

    case rqst.ps.op of

      { ---- 16#0C, page-in ---- }
      network_ps_rqst_pagin: begin
        touched := 0;
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);

        { the packet size }
        data_len := 1024;
        if rqst.pagin.version >= 8 then
          data_len := max(rqst.pagin.page_size, 1024);
        pkt_addr.low := dest_node;
        pkt_addr.high := routing_key;
        data_len := network_$get_pkt_size(pkt_addr, data_len);
        ppp := 1024 div data_len;

        if not (network_service_file in network_$allowed_service.service)
           or else (2 in network_$ps_flag_set_t(pkt_flags)) then
          reply.ps.status.all := status_$network_request_denied_by_remote_node
        else begin
          if rqst_copy_len = 40 then begin
            if rqst.pagin.limit >= 8 then
              touch_count := 32
            else
              touch_count := rqst.pagin.limit;
          end
          else
            touch_count := rqst.pagin.count;
          touch_flags := 2;
          if rqst.pagin.flag_1a then
            touch_flags := 3;

          req.pr := rqst.pagin.req;
          anon := req.pr.uid.high = anon_$uid.high;

          if anon then begin
            area_$touch(req.area, rshft(req.pr.page_num, 5),
                        req.pr.page_num & 16#1F, 0, ppns, st);
            if st.all = status_$ok then begin
              touched := 1;
              mmap_$wire(ppns[1]);
            end;
            ml_$unlock(ml_$pmap_lock);
          end
          else begin
            aste := ast_$activate_and_wire(req.pr.uid, rshft(req.pr.page_num, 5),
                                           st);
            if aste <> nil then begin
              if aste^.aote^.loc_flags < 0 then
                st.all := file_$object_not_found
              else begin
                ml_$lock(ml_$pmap_lock);
                touched := ast_$touch(aste^, dest_node, req.pr.page_num & 16#1F,
                                      touch_count, ppns, st, touch_flags);
                if (touched > 0) and then (st.all = status_$ok) then
                  for i := 1 to touched do
                    mmap_$wire(ppns[i]);
                ml_$unlock(ml_$pmap_lock);

                if touched > 0 then begin
                  reply.ps.loc.uid := req.pr.uid;
                  reply.ps.loc.scratch := false;
                  if rqst.pagin.flag_18 and then (rqst.pagin.version >= 7)
                  then
                    attr_flags := 16#280
                  else
                    attr_flags := 16#80;
                  ast_$get_attributes(reply.floc.loc, attr_flags, attrs, st2);
                  if st2.all <> status_$ok then
                    st := st2;
                  reply.pagin.dtm := attrs.clock_24;
                  reply.pagin.clock := attrs.dta;
                  reply.pagin.acl := attrs.dtu;
                end;
              end;

              aste^.wire_count := aste^.wire_count - 1;
            end;
          end;

          reply.ps.status := st;
        end;

        { the reply }
        reply.pagin.req := rqst.pagin.req;
        reply.pagin.req.reserved_0c := 0;
        reply.pagin.req.reserved_1a := 0;
        reply.pagin.op := network_ps_reply_pagin;
        if rqst.pagin.version < 8 then
          reply.pagin.version := rqst.pagin.version
        else
          reply.pagin.version := 8;
        reply.pagin.more := 0;
        reply.pagin.seq := 1;
        reply.pagin.chksum := 0;
        reply_len := 74;
        pkt_flags := 16#20;
        if touched = 0 then begin
          data_pages[1] := 0;
          data_len := 0;
          network_$ps_send_reply;
          return;
        end;

        { the packets to send }
        npkts := min(ppp * touched - (0 div data_len),
                     (integer32(rqst.pagin.count) * 1024) div data_len);
        if npkts > rqst.pagin.limit then
          reply.pagin.page_cnt := rqst.pagin.limit
        else begin
          reply.pagin.page_cnt := npkts;
          reply.pagin.more := reply.pagin.more ! (-16#8000);
        end;

        if reply.ps.status.all = status_$pmap_page_null then begin
          { the zero page }
          reply.pagin.page_cnt := min(touched, rqst.pagin.count);
          if reply.pagin.version > 1 then begin
            data_pages[1] := 0;
            data_len := 0;
            network_$ps_send_reply;
          end
          else
            for seq := 1 to reply.pagin.page_cnt do begin
              data_pages[1] := network_$zero_page_pa;
              reply.pagin.seq := seq;
              if network_$do_chksum then
                reply.pagin.chksum := get_chksum(data_pages[1], data_len);
              network_$ps_send_reply;
              if st.all <> status_$ok then
                exit;
            end;
        end
        else begin
          if ppp > 1 then begin
            { several packets per page }
            data_pages[1] := lshft(ppns[1], 10);
            k := 1;
            for seq := 1 to reply.pagin.page_cnt do begin
              reply.pagin.seq := seq;
              if network_$do_chksum then
                reply.pagin.chksum := get_chksum(data_pages[1], data_len);
              network_$ps_send_reply;
              if st.all <> status_$ok then
                exit;
              data_pages[1] := data_pages[1] + data_len;
              if (data_pages[1] & 16#3FF) = 0 then begin
                k := k + 1;
                data_pages[1] := lshft(ppns[k], 10);
              end;
            end;
          end
          else
            { a page per packet }
            for seq := 1 to reply.pagin.page_cnt do begin
              data_pages[1] := lshft(ppns[seq], 10);
              reply.pagin.seq := seq;
              if network_$do_chksum then
                reply.pagin.chksum := get_chksum(data_pages[1], data_len);
              network_$ps_send_reply;
              if st.all <> status_$ok then
                exit;
            end;

          ml_$lock(ml_$pmap_lock);
          for i := 1 to touched do
            mmap_$unwire(ppns[i]);
          ml_$unlock(ml_$pmap_lock);
        end;

        network_$mult_pagin_rqst_cnt :=
          network_$mult_pagin_rqst_cnt + reply.pagin.page_cnt;
        proc1_$stats[proc1_$current].stat[4] :=
          proc1_$stats[proc1_$current].stat[4] + reply.pagin.page_cnt;
        if not netlog_$ok_to_log_server then
          return;
        time_$abs_clock(end_clock);
        log_seg := rshft(rqst.pagin.req.page_num, 5);
        log_page := rqst.pagin.req.page_num & 16#1F;
        log.bits.kind := 1;
        netlog_$log_it(16#14, rqst.pagin.req.uid, log_seg, log_page,
                       log.high, log.low,
                       integer32(start_clock.low32 - arrival.low32) div 250,
                       integer32(end_clock.low32 - start_clock.low32) div 250);
      end;

      { ---- 4, page-out ---- }
      network_ps_rqst_pagout: begin
        network_$pagout_rqst_cnt := network_$pagout_rqst_cnt + 1;
        if 2 in network_$ps_flag_set_t(pkt_flags) then begin
          if data_pages[1] <> 0 then
            pkt_$dump_data(data_pages, data_len);
          return;
        end;
        if data_pages[1] = 0 then
          return;

        { a page whose checksum is wrong }
        if network_$do_chksum and then (rqst.pagout.chksum <> 0) and then
           (get_chksum(data_pages[1], data_len) <> rqst.pagout.chksum)
        then begin
          crash_system(status_$network_bad_checksum);
          pkt_$dump_data(data_pages, data_len);
          network_$bad_chksum_cnt := network_$bad_chksum_cnt + 1;
          return;
        end;

        touch_flags := 0;
        if rqst.pagout.flag then
          touch_flags := 1;
        if mmap[rshft(data_pages[1], 10)].wire_count <> 0 then begin
          mmap[rshft(data_pages[1], 10)].wire_count := 0;
          network_$clear_wired := network_$clear_wired + 1;
        end;

        req.pr := rqst.pagout.req;
        anon := req.pr.uid.high = anon_$uid.high;

        if data_len = 1024 then begin
          { the whole page to the object }
          if anon then
            area_$assoc(req.area.area_id,
                        rshft(req.pr.page_num, 5), req.pr.page_num & 16#1F,
                        rshft(data_pages[1], 10), st)
          else
            ast_$assoc(req.pr.uid, rshft(req.pr.page_num, 5), dest_node,
                       req.pr.page_num & 16#1F, touch_flags,
                       rshft(data_pages[1], 10), st);
          if st.all <> status_$ok then
            netbuf_$rtn_dat(data_pages[1])
          else begin
            wp_$calloc(new_ppn, st2);
            if st2.all <> status_$ok then
              crash_system(st2);
            netbuf_$rtn_dat(lshft(new_ppn, 10));
          end;
        end
        else begin
          { a part page into the object's }
          if anon then begin
            area_$touch(req.area, rshft(req.pr.page_num, 5),
                        req.pr.page_num & 16#1F, 0, ppns, st);
            if st.all = status_$ok then begin
              touched := 1;
              mmap_$wire(ppns[1]);
            end;
            ml_$unlock(ml_$pmap_lock);
          end
          else begin
            aste := ast_$activate_and_wire(req.pr.uid, rshft(req.pr.page_num, 5),
                                           st);
            if aste <> nil then begin
              if aste^.aote^.loc_flags < 0 then
                st.all := file_$object_not_found
              else begin
                ml_$lock(ml_$pmap_lock);
                touched := ast_$touch(aste^, dest_node, req.pr.page_num & 16#1F,
                                      1, ppns, st, touch_flags);
                if (touched > 0) and then (st.all = status_$ok) then
                  mmap_$wire(ppns[1]);
                ml_$unlock(ml_$pmap_lock);
              end;
              aste^.wire_count := aste^.wire_count - 1;
            end;
          end;

          if st.all = status_$ok then begin
            copy_dst_pa := lshft(ppns[1], 10);
            copy_src_pa := data_pages[1];
            network_$phys_copy(copy_dst_pa, copy_src_pa, data_len);
            mmap[ppns[1]].modified := true;
            wp_$unwire(ppns[1]);
          end;
          netbuf_$rtn_dat(data_pages[1]);
        end;

        { the reply }
        data_pages[1] := 0;
        data_len := 0;
        reply.ps.status := st;
        reply.ps.op := network_ps_reply_pagout;
        reply.pagout.req := rqst.pagout.req;
        time_$abs_clock(deadline);
        time_$clock(reply.pagout.clock);
        if (reply.ps.status.all = status_$ok) and then not anon then
          discard(ast_$set_dts(16#27, req.pr.uid, deadline, reply.pagout.clock,
                               st));

        reply.pagout.dtm_high := deadline.high;
        reply_len := 52;
        reply.pagout.dtm_bits := 0;
        if rqst.pagout.version >= 4 then
          reply.pagout.dtm_low := deadline.low
        else begin
          reply.pagout.dtm_bits := rshft(deadline.low, 8) & 16#F8;
          reply_len := 44;
        end;
        reply.pagout.zero_1c := 0;
        reply.pagout.zero_20 := 0;
        reply.pagout.version := 8;
        pkt_flags := 8;
        network_$ps_send_reply;

        if (reply.ps.status.all = status_$ok) and then (st.all = status_$ok)
        then
          proc1_$stats[proc1_$current].stat[4] :=
            proc1_$stats[proc1_$current].stat[4] + 1;
        if not netlog_$ok_to_log_server then
          return;
        time_$abs_clock(end_clock);
        log_seg := rshft(req.pr.page_num, 5);
        log_page := req.pr.page_num & 16#1F;
        log.bits.kind := 2;
        netlog_$log_it(16#14, req.pr.uid, log_seg, log_page, log.high, log.low,
                       integer32(start_clock.low32 - arrival.low32) div 250,
                       integer32(end_clock.low32 - start_clock.low32) div 250);
      end;

      { ---- 16#0A, set attribute ---- }
      network_ps_rqst_setattr: begin
        network_$attrib_rqst_cnt := network_$attrib_rqst_cnt + 1;
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);
        if 2 in network_$ps_flag_set_t(pkt_flags) then
          return;
        ast_$set_attribute(rqst.setattr.uid, rqst.setattr.attr_id,
                           rqst.setattr.value, st);
        reply.ps.status := st;
        reply.ps.op := network_ps_reply_setattr;
        time_$abs_clock(deadline);
        if reply.ps.status.all = status_$ok then
          discard(ast_$set_dts(16#23, rqst.setattr.uid, deadline, deadline,
                               st));

        reply.setattr.dtm_high := deadline.high;
        reply.setattr.dtm_low := deadline.low;
        if rqst.setattr.version <= 4 then
          reply.setattr.dtm_low := rshft(reply.setattr.dtm_low, 8) & 16#F8;
        reply.setattr.version := 8;
        reply_len := 14;
        data_pages[1] := 0;
        data_len := 0;
        pkt_flags := 8;
        if network_$service_time + arrival.high < deadline.high then begin
          network_$2long1 := network_$2long1 + 1;
          st.all := status_$network_remote_node_failed_to_respond;
        end
        else
          network_$ps_send_reply;

        if not netlog_$ok_to_log_server or else
           (reply.ps.status.all <> status_$ok) or else
           (st.all <> status_$ok) then
          return;
        time_$abs_clock(end_clock);
        log.bits.kind := 3;
        netlog_$log_it(16#14, rqst.setattr.uid, 0, 0, log.high, log.low,
                       integer32(start_clock.low32 - arrival.low32) div 250,
                       integer32(end_clock.low32 - start_clock.low32) div 250);
      end;

      { ---- 0, echo ---- }
      network_ps_rqst_echo: begin
        os_$data_copy(rqst, reply, rqst_copy_len);
        reply.ps.op := network_ps_reply_echo;
        reply_len := rqst_copy_len;
        pkt_flags := (pkt_flags & (~16#10)) ! 16#20;
        network_$ps_send_reply;
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);
      end;

      { ---- 16#0E, ring information ---- }
      network_ps_rqst_ring_info: begin
        network_$info_rqst_cnt := network_$info_rqst_cnt + 1;
        reply.ps.status.all := status_$ok;
        reply.ps.op := network_ps_reply_ring_info;
        reply.ring.failure_rec := network_$failure_rec;
        reply.ring.stats := ring_$data[0];
        reply.ring.swdiag := ring_$swdiag_data;
        reply.ring.swdiag_rcvcnt := ring_$swdiag_rcvcnt;
        reply.ring.swdiag_nodeid := ring_$swdiag_nodeid;
        reply.ring.xmit_biphase := ring_$xmit_biphase;
        reply.ring.rcv_biphase := ring_$rcv_biphase;
        reply.ring.xmit_esb := ring_$xmit_esb;
        reply.ring.rcv_esb := ring_$rcv_esb;
        reply.ring.kind_00 := 3;
        reply.ring.diskless := network_$diskless;
        reply.ring.mother_node := network_$mother_node;
        pkt_flags := 16#20;
        reply_len := 128;
        network_$ps_send_reply;
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);
      end;

      { ---- 6, attributes ---- }
      network_ps_rqst_getattr: begin
        network_$info_rqst_cnt := network_$info_rqst_cnt + 1;
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);
        reply.ps.op := network_ps_reply_getattr;
        if not (network_service_file in network_$allowed_service.service)
           or else (2 in network_$ps_flag_set_t(pkt_flags)) then
          reply.ps.status.all := status_$network_request_denied_by_remote_node
        else begin
          { the location record }
          if rqst_copy_len = 50 then
            reply.ps.loc := rqst.getattr.loc
          else begin
            reply.ps.loc.uid := rqst.getattr.uid;
            reply.ps.loc.scratch := false;
          end;
          reply.ps.status.all := status_$ok;
          if (rqst.uid_bits.uid_low.bits_27_20 & 16#E0) <> 0 then begin
            if rqst_copy_len = 50 then
              reply.ps.status.all := file_$object_not_found
            else
              reply.loc_bits.uid_low.bits_27_25 := 0;
          end;

          if rqst.getattr.big then
            attr_flags := 16#281
          else
            attr_flags := 16#81;
          if reply.ps.status.all = status_$ok then
            ast_$get_attributes(reply.floc.loc, attr_flags,
                                reply.floc.attrs, reply.ps.status);

          if reply.ps.status.all = status_$ok then begin
            if (rqst.uid_bits.uid_low.bits_27_20 & 16#E0) <> 0 then begin
              if rqst.getattr.version < 5 then begin
                for i := 1 to 16 do
                  reply.ps.old_attrs[i] := 0;
                reply.old.uid := rqst.getattr.uid;
                reply.old.uid2 := rqst.getattr.uid;
                reply.old.kind := 3;
                reply.old.size := 1024;
              end
              else
                reply.ps.status.all := file_$object_not_found;
            end
            else if rqst.getattr.version < 5 then begin
              old_flag := reply.ps.attrs.byte_00 <> 0;
              vtoce_$new_to_old(reply.ps.attrs, old_flag, old_attrs);
              reply.ps.old_attrs := old_attrs;
            end;
          end;
        end;

        data_len := 0;
        data_pages[1] := 0;
        if rqst.getattr.version < 5 then begin
          reply.ps.old_version := 8;
          reply_len := 72;
        end
        else begin
          reply.ps.version := 8;
          reply_len := 184;
        end;
        pkt_flags := 16#20;
        network_$ps_send_reply;

        if not netlog_$ok_to_log_server then
          return;
        time_$abs_clock(end_clock);
        log.bits.kind := 4;
        netlog_$log_it(16#14, rqst.getattr.uid, 0, 0, log.high, log.low,
                       integer32(start_clock.low32 - arrival.low32) div 250,
                       integer32(end_clock.low32 - start_clock.low32) div 250);
      end;

      { ---- otherwise, unknown ---- }
      otherwise begin
        if data_pages[1] <> 0 then
          pkt_$dump_data(data_pages, data_len);
        reply.ps.op := network_ps_reply_unknown;
        reply.ps.status.all := status_$network_unknown_request_type;
        reply.ps.version := 8;
        data_len := 0;
        data_pages[1] := 0;
        pkt_flags := 16#20;
        reply_len := 8;
        network_$ps_send_reply;
      end;
    end;
  end;
