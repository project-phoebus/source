{ ring_$setup_tx - copy a packet into the controller's transmit area.

  Image addresses:
    sau7  0x3C48E3DE  ring_$setup_tx (module-local)
    sau8  0x03C81BDE  ring_$setup_tx (module-local)
    sau9  0x3C47D7DE  ring_$setup_tx (module-local)

  Assume we're called with the unit's buffer lock held.

  - The header and the data pages (up to 512 words each) go to the
    unit's transmit area, each transfer checked for parity errors.
  - Without data_va each data page is mapped for its copy
    (NETBUF_$GETVA); with it the pages follow data_va in memory.
  - The transmit counters get the header's and the packet's word counts.
  - With `parity_dma_page_pairs' each transfer's page goes to PARITY_ as
    one of the channel's two: the header's as the first, a data page as
    the second.

  Returns:
    0: the packet is in the controller
    status_$network_memory_parity_error_during_transmit: a copy took a
      parity error
    NETBUF_$GETVA's status: a data page could not be mapped

  Status stored: none.
}

function ring_$setup_tx(hdr: univ_ptr; hdr_len: pinteger;
                        hdr_pa: integer32;
                        in data_pages: pkt_$data_pages_t;
                        data_va: integer32; data_len: pinteger;
                        var hw: ring8_$csr_t; socket: integer):
  integer32;
  internal;
var
  page_va: integer32;
  status: status_$t;
  ppn: integer32;
  ctlr_addr: pinteger;
  hdr_words: integer;
  data_words: integer;
  left: integer;
  n: integer;
  parity_err: boolean;
  i: integer;
  addr_w: pinteger;
begin
  ctlr_addr := ring_$ctl[socket].cmd_addr;
  hdr_words := (hdr_len + 1) div 2;
  data_words := (data_len + 1) div 2;

  { the header }
  ppn := rshft(hdr_pa, 10);
%if parity_dma_page_pairs %then
  parity_$set_state(1, ppn, 0);
%else
  parity_$set_state(1, ppn, 1);
%endif
  ring_$rb_to(hw, ctlr_addr, hdr, hdr_words);
  ctlr_addr := ctlr_addr + hdr_words;
%if parity_dma_page_pairs %then
  parity_err := parity_$chk_io(1, ppn, 0) <> 0;
%else
  parity_err := parity_$chk_io(1) <> 0;
%endif
  if parity_err then begin
    ring_$setup_tx := status_$network_memory_parity_error_during_transmit;
    return;
  end;

  { the data, a page at a time }
  left := data_words;
  page_va := data_va;
  i := 1;
  while left > 0 do begin
    if data_va = 0 then begin
      netbuf_$getva(data_pages[i], page_va, status);
      if status.all <> 0 then begin
        ring_$setup_tx := status.all;
        return;
      end;
    end;
    ppn := rshft(data_pages[i], 10);
%if parity_dma_page_pairs %then
    parity_$set_state(1, 0, ppn);
%else
    parity_$set_state(1, ppn, 1);
%endif
    if left > 512 then
      n := 512
    else
      n := left;
    ring_$rb_to(hw, ctlr_addr, univ_ptr(page_va), n);
    if data_va = 0 then
      discard(netbuf_$rtnva(page_va))
    else
      page_va := page_va + 1024;
%if parity_dma_page_pairs %then
    parity_err := parity_$chk_io(1, 0, ppn) <> 0;
%else
    parity_err := parity_$chk_io(1) <> 0;
%endif
    if parity_err then begin
      ring_$setup_tx := status_$network_memory_parity_error_during_transmit;
      return;
    end;
    i := i + 1;
    left := left - 512;
    ctlr_addr := ctlr_addr + 512;
  end;

  { the counts, and the controller pointed at the area }
  ring_$set_timer(hdr_words, ring8_cnt_tx_hdr, hw);
  ring_$set_timer(hdr_words + data_words, ring8_cnt_tx_end, hw);
  addr_w := ring_$ctl[socket].cmd_addr;
  hw.cmd_ptr := lshft(addr_w & 16#FF, 8) + rshft(addr_w, 8);
  ring_$setup_tx := 0;
end;
