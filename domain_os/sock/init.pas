{ SOCK_$INIT - set up the socket descriptors.

  Image addresses:
    sau2  0x00E2FDF0  SOCK_$INIT

  - Each socket 1..224 gets its pointer entry, its eventcount and its
    number; the dynamic sockets (32 and up) go on the free list.
  - SOCK's block is reached by its address (another section's block;
    sock/sock.pas).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure sock_$init;
var
  i: integer;
begin
  for i := 1 to sock_max_number do
    with sock_$socket[i] do begin
      sock_$socket_ptr[i] := addr(ec);
      ec_$init(ec);
      flags.number := i;
      if i >= sock_first_dynamic then begin
        queue_head := sock_list.free_head;
        sock_list.free_head := integer32(addr(ec));
      end;
    end;
end;
