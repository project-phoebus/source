{ ethernet_rcv_packet - take a received packet from the adapter into the
  unit's header and data pages.

  Image addresses:
    sau7  0x3C491F1E  drain (nested)
    sau8  0x03C8571A  drain (nested)
    sau9  0x3C48131A  drain (nested)
    sau6  0x78087B18  ethernet_rcv_packet
    sau7  0x3C491F98  ethernet_rcv_packet
    sau8  0x03C85794  ethernet_rcv_packet
    sau9  0x3C481394  ethernet_rcv_packet

  - The packet's bytes come through the data register (HCR DIR set
    while they do).  The Ethernet header goes to the header page after
    its first word; the source address and type are kept in the unit.
  - A Domain packet (type 16#8019): its Domain header replaces the
    Ethernet header at the page's start, the header's length taken from
    it; another packet: up to 936 bytes after the Ethernet header, and
    the page's first word gets the tag in its top 11 bits.  The rest, up
    to a page, goes to the unit's data page through its window in
    ETHERNET_$BUFFER; with no rest the data page is kept back.
  - A packet too long, or with too long a header or rest, is counted and
    drained (its bytes read and dropped).
  - The rest's read is not checked.
  - With `ethernet_vme': the packet is copied from the receive buffer
    the controller filled (rcv_va[rcv_idx]), the rest through a page
    NETBUF_$GETVA maps; a packet too long is dropped uncounted.

  Status stored:
    status_$ok: the packet was taken, or its rest's read failed
    status_$eth_adapter_hardware_error: it was too long
    ethernet_$$pio_read's status: a header read failed
}

%if ethernet_vme %then
procedure ethernet_rcv_packet(u: ethernet_$unit_ptr_t; len: integer;
                              tag: integer; out status: status_$t);
  internal;
var
  p: pkt_$bytes_ptr_t;
  src: integer32;
  h: ethernet_$rcv_hdr_ptr_t;
  rest: pinteger;
  n: pinteger;
begin
  status.all := status_$ok;
  mmu_$mcr_change(4);
  if len > 1514 then
    status.all := status_$eth_adapter_hardware_error
  else begin
    src := integer32(u^.rcv_va[u^.rcv_idx]);
    h := ethernet_$rcv_hdr_ptr_t(u^.hdr_va);
    p := addr(h^.eth);
    os_$data_copy(pkt_$bytes_ptr_t(src)^, p^, 14);
    src := src + 14;
    rest := len - 14;
    u^.rcv_src := h^.eth.src;
    if u^.rcv_src.ptype = eth_type_domain then begin
      src := src + 30;
      rest := rest - 30;
      p := pkt_$bytes_ptr_t(h);
      os_$data_copy(pkt_$bytes_ptr_t(src)^, p^, 24);
      n := (h^.hdr_len + 1) & ~1;
      src := src + 24;
      if n > 952 then begin
        status.all := status_$eth_adapter_hardware_error;
        return;
      end;
      p := addr(h^.bytes[24]);
      os_$data_copy(pkt_$bytes_ptr_t(src)^, p^, n - 24);
      src := src + n - 24;
      u^.rcv_hdr_len := h^.hdr_len;
      u^.rcv_data_len := h^.data_len;
    end
    else begin
      n := rest;
      if n > 936 then
        n := 936;
      p := addr(h^.bytes[16]);
      os_$data_copy(pkt_$bytes_ptr_t(src)^, p^, n);
      src := src + n;
      u^.rcv_hdr_len := 14 + n;
      len := len - (14 + n);
      u^.rcv_data_len := len;
      h^.tag.tag := tag;
    end;
    rest := rest - n;
    if rest > 1024 then
      status.all := status_$eth_adapter_hardware_error
    else begin
      if rest <> 0 then begin
        netbuf_$getva(u^.dat_va, u^.rcv_map_va, status);
        ethernet_check_status(status);
        os_$data_copy(pkt_$bytes_ptr_t(src)^,
                      pkt_$bytes_ptr_t(u^.rcv_map_va)^, rest);
        discard(netbuf_$rtnva(u^.rcv_map_va));
      end
      else begin
        u^.spare_dat := u^.dat_va;
        u^.dat_va := 0;
      end;
      status.all := status_$ok;
    end;
  end;
end;
%else
procedure ethernet_rcv_packet(u: ethernet_$unit_ptr_t; len: integer;
                              tag: integer; out status: status_$t);
  internal;
label
  done;
var
  old_sr: integer;
  h: ethernet_$rcv_hdr_ptr_t;
  rest: pinteger;
  n: pinteger;

  { drain - map the data page into the unit's window and read len more
    bytes of the packet into it, a page at a time, to drop them. }
  procedure drain(u: ethernet_$unit_ptr_t; len: integer);
  var
    n: integer;
    st: status_$t;
  begin
    old_sr := set_sr(16#2700);
    mmu_$set_pmape(univ_ptr(u^.buf2_va), u^.buf2_pmape,
                   rshft(u^.dat_va, 10));
    discard(set_sr(old_sr));
    while len <> 0 do begin
      n := len;
      if n > 1024 then
        n := 1024;
      if not ethernet_$$pio_read(u^.regs, univ_ptr(u^.buf2_va), n, st) then
        exit;
      len := len - n;
    end;
  end;

begin
  status.all := status_$ok;
  mmu_$mcr_change(4);
  u^.regs^.control := u^.regs^.control ! eth_hcr_dir;
  if len > 1514 then begin
    status.all := status_$eth_adapter_hardware_error;
    u^.stats.counts[6] := u^.stats.counts[6] + 1;
    drain(u, len);
  end
  else begin
    h := ethernet_$rcv_hdr_ptr_t(u^.hdr_va);
    if not ethernet_$$pio_read(u^.regs, addr(h^.eth), 14, status) then
      goto done;
    rest := len - 14;
    u^.rcv_src := h^.eth.src;
    if u^.rcv_src.ptype = eth_type_domain then begin
      if not ethernet_$$pio_read(u^.regs, h, 30, status) then
        goto done;
      rest := rest - 30;
      if not ethernet_$$pio_read(u^.regs, h, 24, status) then
        goto done;
      n := (h^.hdr_len + 1) & ~1;
      if n > 952 then begin
        status.all := status_$eth_adapter_hardware_error;
        u^.stats.counts[6] := u^.stats.counts[6] + 1;
        drain(u, rest - 24);
        goto done;
      end;
      if not ethernet_$$pio_read(u^.regs, addr(h^.bytes[24]), n - 24,
                                 status) then
        goto done;
      u^.rcv_hdr_len := h^.hdr_len;
      u^.rcv_data_len := h^.data_len;
    end
    else begin
      n := rest;
      if n > 936 then
        n := 936;
      if not ethernet_$$pio_read(u^.regs, addr(h^.bytes[16]), n, status) then
        goto done;
      u^.rcv_hdr_len := 14 + n;
      len := len - (14 + n);
      u^.rcv_data_len := len;
      h^.tag.tag := tag;
    end;
    rest := rest - n;
    if rest > 1024 then begin
      status.all := status_$eth_adapter_hardware_error;
      u^.stats.counts[6] := u^.stats.counts[6] + 1;
      drain(u, rest);
      goto done;
    end;
    if rest <> 0 then begin
      old_sr := set_sr(16#2700);
      mmu_$set_pmape(univ_ptr(u^.buf2_va), u^.buf2_pmape,
                     rshft(u^.dat_va, 10));
      discard(set_sr(old_sr));
      discard(ethernet_$$pio_read(u^.regs, univ_ptr(u^.buf2_va), rest,
                                  status));
    end
    else begin
      u^.spare_dat := u^.dat_va;
      u^.dat_va := 0;
    end;
    status.all := status_$ok;
  end;
done:
  u^.regs^.control := u^.regs^.control & ~eth_hcr_dir;
end;
%endif
