{ SOCK_$ALLOCATE - allocate a socket from the free list.

  Image addresses:
    sau2  0x00E15E62  SOCK_$ALLOCATE

  - Under the socket lock the first free descriptor is taken, allocated
    and open with an empty queue; its pages are added to the buffer pool
    after the lock.
  - The result is false, and sock_num 0, when the free list is empty.

  Status stored: none.
}

{ TODO(pascal) 2 frame bytes of SOCK_$ALLOCATE hold nothing addressed

  The stand-in unused_8 holds them.  Only token is addressed in the
  frame; sock_view and the result variable account for two more words
  by this reading.  Not settled. }

function sock_$allocate(out sock_num: pinteger; max_queue: integer;
                        hdr_pages: integer; data_pages: integer;
                        max_data_len: integer): boolean;
var
  sock_view: sock_$sock_ptr_t;
  token: pinteger;
  unused_8: integer;                      { stand-in: TODO above }
begin
  token := ml_$spin_lock(sock_lock);
  if sock_list.free_head = 0 then begin
    ml_$spin_unlock(sock_lock, token);
    sock_num := 0;
    sock_$allocate := false;
  end
  else begin
    sock_view := sock_$sock_ptr_t(sock_list.free_head);
    sock_list.free_head := sock_view^.queue_head;
    sock_view^.flags.allocated := true;
    sock_view^.queue_head := 0;
    sock_view^.queue_tail := 0;
    sock_view^.flags.open := true;
    sock_view^.data_pages := data_pages;
    sock_view^.hdr_pages := hdr_pages;
    sock_view^.max_data_len := max_data_len;
    sock_view^.max_queue := max_queue;

    ml_$spin_unlock(sock_lock, token);
    sock_num := sock_view^.flags.number;
    if (hdr_pages ! data_pages) <> 0 then
      netbuf_$add_pages(hdr_pages, data_pages);
    sock_$allocate := true;
  end;
end;
