{ SOCK_$OPEN - open a socket of a given number.

  Image addresses:
    sau2  0x00E15D8C  SOCK_$OPEN

  - Under the socket lock the socket is allocated, unlinked from the
    free list (a dynamic socket, 32 and up), its queue emptied and its
    counts set; its pages are added to the buffer pool after the lock.
  - The result is false for a socket allocated already.
  - The free-list walk's p starts at SOCK_LIST, whose free head sits at
    a descriptor's queue_head offset (sock/sock.ins.pas sock_$list_t).

  Status stored: none.
}

function sock_$open(sock_num: pinteger; max_queue: integer;
                    hdr_pages: integer; data_pages: integer;
                    max_data_len: integer): boolean;
var
  sock_view: sock_$sock_ptr_t;
  token: pinteger;
  p: sock_$sock_ptr_t;
begin
  sock_view := sock_$socket_ptr[sock_num];
  token := ml_$spin_lock(sock_lock);
  if sock_flag_allocated in sock_view^.flags.members then begin
    ml_$spin_unlock(sock_lock, token);
    sock_$open := false;
  end
  else begin
    sock_view^.flags.allocated := true;
    sock_view^.max_queue := 0;
    if sock_view^.flags.number >= sock_first_dynamic then begin
      p := sock_$sock_ptr_t(addr(sock_list));
      while p^.queue_head <> integer32(sock_view) do
        p := sock_$sock_ptr_t(p^.queue_head);
      p^.queue_head := sock_view^.queue_head;
    end;
    sock_view^.queue_head := 0;
    sock_view^.queue_tail := 0;
    sock_view^.data_pages := data_pages;
    sock_view^.hdr_pages := hdr_pages;
    sock_view^.max_data_len := max_data_len;
    sock_view^.flags.open := true;
    sock_view^.max_queue := max_queue;

    ml_$spin_unlock(sock_lock, token);
    if (hdr_pages <> 0) or else (data_pages <> 0) then
      netbuf_$add_pages(hdr_pages, data_pages);
    sock_$open := true;
  end;
end;
