{ SOCK_$PUT - queue a packet on a socket and wake its waiters.

  Image addresses:
    sau2  0x00E1614E  SOCK_$PUT

  - The socket's eventcount is advanced when SOCK_$PUT_INT queued the
    packet.

  Status stored: none.
}

function sock_$put(sock_num: pinteger; in info: sock_$pkt_info_t;
                   flags: boolean; ec_param1: integer;
                   ec_param2: integer): boolean;
var
  ec: ec_$eventcount_ptr_t;
begin
  if sock_$put_int(sock_num, info, flags, ec_param1, ec_param2, ec)
  then begin
    ec_$advance(ec^);
    sock_$put := true;
  end
  else
    sock_$put := false;
end;
