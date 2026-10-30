{ xns_$pkt_bufs_in_netbuf_pool - whether every buffer of a received
  packet lies in the network buffer window.

  Image addresses:
    sau2  0x00E17876  xns_$pkt_bufs_in_netbuf_pool

  - False at the first buffer of the packet's chain whose address lies
    outside [XNS_ERROR's low bound, its high bound), else true.
  - The SAU2 frame has 4 bytes no object explains, the stand-in
    unused_c (the TODO in xns/is_local_addr.pas).

  Status stored: none.
}

function xns_$pkt_bufs_in_netbuf_pool(in pkt: xns_$pkt_desc_t): boolean;
  internal;
var
  node: xns_$buf_desc_ptr_t;
  unused_c: integer32;                    { stand-in }
begin
  xns_$pkt_bufs_in_netbuf_pool := true;
  node := addr(pkt.head);

  while node <> nil do begin
    if (node^.address < integer32(xns_error_$buf_va_low))
       or else (node^.address >= integer32(xns_error_$buf_va_high)) then
    begin
      xns_$pkt_bufs_in_netbuf_pool := false;
      return;
    end;
    node := node^.next;
  end;
end;
