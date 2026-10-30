{ SOCK_$ALLOCATE_USER - allocate a socket for a user process.

  Image addresses:
    sau2  0x00E15F14  SOCK_$ALLOCATE_USER

  - Only while user sockets remain (sock_user_limit); the socket is
    marked a user socket.  The result is false, and sock_num 0, when
    none is given.

  Status stored: none.
}

function sock_$allocate_user(out sock_num: pinteger; max_queue: integer;
                             hdr_pages: integer; data_pages: integer;
                             max_data_len: integer): boolean;
var
  sock_view: sock_$sock_ptr_t;
begin
  if (sock_user_limit <> 0)
     and then sock_$allocate(sock_num, max_queue, hdr_pages, data_pages,
                             max_data_len) then begin
    sock_user_limit := sock_user_limit - 1;
    sock_view := sock_$socket_ptr[sock_num];
    sock_view^.flags.user_mode := true;
    sock_$allocate_user := true;
  end
  else begin
    sock_num := 0;
    sock_$allocate_user := false;
  end;
end;
