{ ring_8025_queue_nullsap - queue a frame to the null SAP for its answer.

  Image addresses:
    sau7  0x3C49762A  ring_8025_queue_nullsap
    sau8  0x03C8AC4A  ring_8025_queue_nullsap
    sau9  0x3C48684E  ring_8025_queue_nullsap

  - The frame (its header page and data pages) goes on the unit's null
    SAP queue; when the queue is full its pages are given back instead.
  - Either way RING_8025_$NULLSAP_HELPER is queued on the wired DXM
    queue with the unit's number.

  Status stored: none.
}

procedure ring_8025_queue_nullsap(u: ring_8025_$unit_ptr_t; va: integer32;
                                  pa: integer32; hlen: integer;
                                  in pages: pkt_$data_pages_t;
                                  dlen: integer);
  internal;
var
  status: status_$t;
  unit: integer;
  n: integer;
  i: integer;
begin
  ml_$exclusion_start(u^.nullsap_lock);
  if u^.nullsap_count < r8025_nullsap_slots then begin
    with u^.nullsap_q[u^.nullsap_in] do begin
      hdr_va := va;
      hdr_pa := pa;
      hdr_len := hlen;
      data_pages := pages;
      data_len := dlen;
    end;
    u^.nullsap_count := u^.nullsap_count + 1;
    u^.nullsap_in := (u^.nullsap_in + 1) & 7;
  end
  else begin
    netbuf_$rtn_hdr(va);
    n := dlen;
    i := 1;
    while n <> 0 do begin
      netbuf_$rtn_dat(pages[i]);
      i := i + 1;
      n := n - min(n, 1024);
    end;
  end;
  ml_$exclusion_stop(u^.nullsap_lock);
  unit := u^.cnum;
  dxm_$add_callback(dxm_$wired_q, addr(ring_8025_$nullsap_helper),
                    addr(unit), 2, true, status);
end;
