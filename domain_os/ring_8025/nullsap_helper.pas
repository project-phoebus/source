{ RING_8025_$NULLSAP_HELPER - answer the frames sent to the null SAP.

  Image addresses:
    sau8  0x03C8A906  RING_8025_$NULLSAP_HELPER
    sau9  0x3C48650A  RING_8025_$NULLSAP_HELPER

  - Runs from the wired DXM queue (ring_8025_queue_nullsap), and answers
    every frame of the unit's null SAP queue until it is empty.
  - The answer goes back to the frame's source, its route reversed (a
    single-route broadcast is answered by an all-routes broadcast) when
    the unit uses source routing; the LLC header has the SAPs swapped,
    the response bit set.  An XID is answered with this node's LLC
    classes and no data; any other frame (a TEST) with its information
    field and its data.
  - Nothing is sent while the unit is not started.  The frame's pages
    are given back.
  - The XID path's data pages are counted down by the remainder of the
    previous pass's page loop (n), not by the frame's own length.

  Status stored: none.
}

procedure ring_8025_$nullsap_helper(in unit_ptr: ring_8025_$unit_num_ptr_t);
var
  pages: pkt_$data_pages_t;
  pieces: array[1..5] of ring_8025_$xmit_piece_t;
  dst_info: integer32;
  src_info: integer32;
  status: status_$t;
  va: integer32;
  rva: integer32;
  pa: integer32;
  ohdr: ring_8025_$mac_hdr_ptr_t;
  len: pinteger;
  hlen: pinteger;
  chunk: pinteger;
  fstat: integer;
  u: ring_8025_$unit_ptr_t;
  rllc: ring_8025_$llc_ptr_t;
  ollc: ring_8025_$llc_ptr_t;
  rif_len: integer32;
  orif_len: integer32;
  info_len: integer;
  frame_size: integer;
  count: integer;
  dlen: pinteger;
  n: pinteger;
  m: pinteger;
  i: integer;
  j: integer;
begin
  u := addr(ring8025_ucb[unit_ptr^]);
  repeat

    { the next queued frame, or done }
    ml_$exclusion_start(u^.nullsap_lock);
    if u^.nullsap_count <> 0 then begin
      with u^.nullsap_q[u^.nullsap_out] do begin
        rva := hdr_va;
        hlen := hdr_len;
        pages := data_pages;
        dlen := data_len;
      end;
      u^.nullsap_count := u^.nullsap_count - 1;
      u^.nullsap_out := (u^.nullsap_out + 1) & 7;
      ml_$exclusion_stop(u^.nullsap_lock);
    end
    else begin
      ml_$exclusion_stop(u^.nullsap_lock);
      return;
    end;

    if r8025_unit_online in u^.flags then begin

      { the answer's MAC header, back to the source }
      netbuf_$get_hdr(pa, va);
      ohdr := ring_8025_$mac_hdr_ptr_t(va);
      rif_len := 0;
      with ring_8025_$mac_hdr_ptr_t(rva)^ do begin
        if src.rii then begin
          src.rii := false;
          rif_len := rif.rc.len;
        end;
        ohdr^.ac := r8025_ac;
        ohdr^.fc := r8025_fc_llc;
        ohdr^.dest.high := src.high;
        ohdr^.dest.low := src.low;
        ohdr^.src.high := r8025_addr_high;
        ohdr^.src.low := node_$me;
        if (rif_len <> 0) and then (rif_len <> 2) and then u^.routing then
          begin
          if (not rif.rc.bcast) or else (not rif.rc.single) then begin
            for j := 1 to rif_len do
              ohdr^.rif.bytes[j] := rif.bytes[j];
            ohdr^.rif.rc.dir := not rif.rc.dir;
            ohdr^.rif.rc.bcast := false;
            orif_len := rif_len;
          end
          else begin
            ohdr^.rif.rc_word := r8025_rc_all_routes;
            orif_len := 2;
          end;
          ohdr^.src.rii := true;
        end
        else
          orif_len := 0;
        rllc := ring_8025_$llc_ptr_t(integer32(addr(rif)) + rif_len);
      end;

      { the LLC header, the SAPs swapped }
      ollc := ring_8025_$llc_ptr_t(integer32(addr(ohdr^.rif)) + orif_len);
      ollc^.dsap := rllc^.ssap;
      ollc^.ssap := rllc^.dsap ! r8025_llc_response;
      ollc^.ctl := rllc^.ctl;
      if (ollc^.ctl & r8025_llc_xid) = r8025_llc_xid then begin
        with ollc^ do begin
          xid_format := r8025_xid_format;
          xid_class := u^.llc_class;
          xid_window := 0;
        end;
        if dlen <> 0 then begin
          i := 1;
          while dlen <> 0 do begin
            netbuf_$rtn_dat(pages[i]);
            i := i + 1;
            dlen := dlen - min(n, 1024);
          end;
        end;
        len := orif_len + 20;
        dlen := 0;
      end
      else begin
        info_len := hlen - 14 - rif_len - 3;
        if info_len <> 0 then begin
          src_info := integer32(rllc) + 3;
          dst_info := integer32(ollc) + 3;
          os_$data_copy(pkt_$bytes_ptr_t(src_info)^,
                        pkt_$bytes_ptr_t(dst_info)^, info_len);
        end;
        len := hlen - rif_len + orif_len;
      end;

      { sent: the header, then the data pages }
      ml_$exclusion_start(u^.xmit_lock);
      frame_size := len + dlen;
      pieces[1].pa := pa;
      pieces[1].cnt.len := len;
      count := 1;
      m := dlen;
      while m <> 0 do begin
        count := count + 1;
        chunk := min(m, 1024);
        pieces[count].pa := pages[count - 1];
        pieces[count].cnt.len := chunk;
        m := m - chunk;
      end;
      ring_8025_transmit(u, frame_size, pieces, count, ohdr^.dest, fstat,
                         status);
      ml_$exclusion_stop(u^.xmit_lock);
      netbuf_$rtn_hdr(va);
    end;

    { the frame's pages back }
    netbuf_$rtn_hdr(rva);
    n := dlen;
    i := 1;
    while n <> 0 do begin
      netbuf_$rtn_dat(pages[i]);
      i := i + 1;
      n := n - min(n, 1024);
    end;
  until false;
end;
