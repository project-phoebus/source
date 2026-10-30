{ SOCK_$CLOSE - close a socket.

  Image addresses:
    sau2  0x00E15F72  SOCK_$CLOSE

  - Its queued packets' buffers are returned and its pages taken from
    the buffer pool, outside the socket lock.
  - A user socket gives its user slot back; a dynamic socket (32 and up)
    goes back on the free list's head.

  Status stored: none.
}

procedure sock_$close(sock_num: pinteger);
var
  pkt_info: sock_$pkt_info_t;
  token: pinteger;
  sock_view: sock_$sock_ptr_t;
begin
  sock_view := sock_$socket_ptr[sock_num];
  token := ml_$spin_lock(sock_lock);
  sock_view^.flags.allocated := false;
  ml_$spin_unlock(sock_lock, token);

  { the queue and the pages }
  if sock_view^.queue_count <> 0 then
    while sock_$get(sock_num, pkt_info) do begin
      netbuf_$rtn_hdr(pkt_info.hdr);
      if pkt_info.data_pages[1] <> 0 then
        pkt_$dump_data(pkt_info.data_pages, pkt_info.data_len);
    end;
  if (sock_view^.hdr_pages ! sock_view^.data_pages) <> 0 then
    netbuf_$del_pages(sock_view^.hdr_pages, sock_view^.data_pages);

  token := ml_$spin_lock(sock_lock);
  if sock_flag_user_mode in sock_view^.flags.members then begin
    sock_user_limit := sock_user_limit + 1;
    sock_view^.flags.user_mode := false;
  end;
  sock_view^.max_queue := 0;
  if sock_num >= sock_first_dynamic then begin
    sock_view^.queue_head := sock_list.free_head;
    sock_list.free_head := integer32(sock_view);
  end;
  ml_$spin_unlock(sock_lock, token);
end;
