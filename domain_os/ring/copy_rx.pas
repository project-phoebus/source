{ ring_$copy_rx - copy a received packet out of the controller.

  Image addresses:
    sau7  0x3C48E58A  ring_$copy_rx (module-local)
    sau8  0x03C81D8A  ring_$copy_rx (module-local)
    sau9  0x3C47D97C  ring_$copy_rx (module-local)

  - The lengths come from the receive counters if the interrupt did not
    record them; the header (up to 952 bytes) is copied unless it was.
  - The data (up to twice max_data_words bytes, none if the header says
    so) go to data_pages through the unit's receive page.
  - The unit's buffer lock is held from the first copy to the end.

  Status stored: none.
}

procedure ring_$copy_rx(var buf: ring8_$rx_buf_t; var unit: ring_$unit_t;
                        var data_pages: pkt_$data_pages_t);
  internal;
var
  regs: ring8_$csr_ptr_t;
  locked: boolean;
  hdr_bytes: integer;
  data_bytes: integer;
  hdr: pkt_$hdr_ptr_t;
  ctlr_addr: pinteger;
  i: integer;
  n: integer;
begin
  locked := false;
  regs := unit.hw_regs;
  if buf.hdr_len = 0 then begin
    buf.hdr_len := ring_$read_timer(regs^, ring8_cnt_rx_hdr) + 4;
    buf.data_len := ring_$read_timer(regs^, ring8_cnt_rx_data) + 1;
  end;
  if buf.hdr_len > 952 then
    hdr_bytes := 952
  else
    hdr_bytes := buf.hdr_len;
  if buf.data_len > unit.max_data_words * 2 then
    data_bytes := unit.max_data_words * 2
  else
    data_bytes := buf.data_len;

  { the header }
  if not buf.copied then begin
    ml_$exclusion_start(unit.buf_lock);
    locked := true;
    ring_$rb_from(regs^, buf.ctlr_addr, univ_ptr(buf.hdr_va),
                  hdr_bytes div 2);
    buf.copied := true;
    hdr := pkt_$hdr_ptr_t(buf.hdr_va);
    if (1 in hdr^.flag_bits.info_bits)
       and then (4 in hdr^.flag_bits.info_bits) then begin
      ring_$swdiag_rcvcnt := ring_$swdiag_rcvcnt + 1;
      ring_$swdiag_nodeid := hdr^.src_node;
      if (buf.rx_status * [2..4, 8..11, 15] = [])
         and then not (10 in buf.status) then
        ring_$swdiag_goodrcv_cnt := ring_$swdiag_goodrcv_cnt + 1;
    end;
  end;

  { the data }
  if pkt_$hdr_ptr_t(buf.hdr_va)^.pkt_data_len = 0 then
    buf.data_len := 0;
  if buf.data_len <> 0 then begin
    if not locked then begin
      ml_$exclusion_start(unit.buf_lock);
      locked := true;
    end;
    ctlr_addr := hdr_bytes div 2 + buf.ctlr_addr;
    i := 1;
    while data_bytes > 0 do begin
      mmu_$set_pmape(unit.rcv_page, unit.rcv_pmape,
                     rshft(data_pages[i], 10));
      if data_bytes > 1024 then
        n := 1024
      else
        n := data_bytes;
      ring_$rb_from(regs^, ctlr_addr, unit.rcv_page, n div 2);
      i := i + 1;
      ctlr_addr := ctlr_addr + 512;
      data_bytes := data_bytes - 1024;
    end;
  end;

  if locked then
    ml_$exclusion_stop(unit.buf_lock);
end;
