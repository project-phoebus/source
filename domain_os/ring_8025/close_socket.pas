{ ring_8025_close_socket - close a channel's socket.

  Image addresses:
    sau9  0x3C486F6C  ring_8025_close_socket
}

procedure ring_8025_close_socket(sock: pinteger); internal;
begin
  sock_$close(sock);
end;
