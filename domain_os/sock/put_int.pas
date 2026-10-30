{ SOCK_$PUT_INT - check a socket number and queue a packet.

  Image addresses:
    sau2  0x00E16190  SOCK_$PUT_INT

  - A socket number outside 1..224 gives false; else ec_ret gets the
    socket's eventcount, and the result is whether SOCK_$PUT_INT_INT
    queued the packet.  With flags set, the socket's queue count is
    written into byte 0x0F of the packet's header.

  Status stored: none.
}

{ sock_num is a pinteger: the number is tested signed against 0 (the
  original compiler compares a 0..65535 word with 0 by signed branches),
  unsigned against 224.

  TODO(pascal) SOCK_$PUT_INT's 4 frame bytes: the stand-in unused_8
  holds 4 frame bytes nothing addresses.  Not settled. }

function sock_$put_int(sock_num: pinteger; in info: sock_$pkt_info_t;
                       flags: boolean; ec_param1: integer;
                       ec_param2: integer;
                       out ec_ret: ec_$eventcount_ptr_t): boolean;
var
  sock_view: sock_$sock_ptr_t;
  unused_8: integer32;                    { stand-in: TODO above }
begin
  if (sock_num <= 0) or else (sock_num > sock_max_number) then
    sock_$put_int := false
  else begin
    sock_view := sock_$socket_ptr[sock_num];
    ec_ret := addr(sock_view^.ec);
    if flags then
      sock_$hdr_bytes_ptr_t(info.hdr)^[15] := sock_view^.queue_count;
    sock_$put_int := sock_$put_int_int(sock_view, info, flags, ec_param1,
                                       ec_param2) = 0;
  end;
end;
