{ SOCK_$GET - take the next packet off a socket's queue.

  Image addresses:
    sau2  0x00E16070  SOCK_$GET

  - The first header page is unlinked under the socket lock, and the
    packet's record filled from the page's queue fields after it.  The
    result is false for an empty queue.

  Status stored: none.
}

{ TODO(pascal) the length words copied as one longword, and 2 frame bytes

  info.data_len and info.hdr_len (0x2A, 0x2C) are copied from the page's
  data_len and hdr_len (0x3E8, 0x3EA) as one longword; SOCK_$PUT_INT_INT
  does the reverse.  Two adjacent word assignments merged, or one 4-byte
  field in both records, which MAC_$DEMUX's word stores and
  MAC_$RECEIVE's word reads speak against.  Read as two assignments.
  The stand-in unused_10 holds 2 frame bytes no object of this reading
  explains.  Not settled. }

function sock_$get(sock_num: pinteger; out info: sock_$pkt_info_t): boolean;
var
  sock_view: sock_$sock_ptr_t;
  token: pinteger;
  netbuf: netbuf_$hdr_page_ptr_t;
  i: integer;
  unused_10: integer;                     { stand-in: TODO above }
begin
  token := ml_$spin_lock(sock_lock);
  sock_view := sock_$socket_ptr[sock_num];
  if sock_view^.queue_count = 0 then begin
    ml_$spin_unlock(sock_lock, token);
    sock_$get := false;
  end
  else begin
    sock_view^.queue_count := sock_view^.queue_count - 1;
    netbuf := netbuf_$hdr_page_ptr_t(sock_view^.queue_head);
    sock_view^.queue_head := netbuf^.next;
    if sock_view^.queue_head = 0 then
      sock_view^.queue_tail := 0;
    ml_$spin_unlock(sock_lock, token);

    with netbuf^ do begin
      info.src_addr := src_addr;
      info.src_port := src_port;
      info.dst_addr := dst_addr;
      info.flags := dst_port;
      info.hdr := hdr_ptr;
      info.data_len := data_len;
      info.hdr_len := hdr_len;
      info.data_pages := data_ptrs;
      info.n_hops := hop_count;
      for i := 0 to info.n_hops - 1 do
        info.hops[i] := hops[i];
    end;
    sock_$get := true;
  end;
end;
