{ NET_IO_$PUT_IN_SOCK_INT - deliver a received packet to a socket of
  this node, at interrupt level.

  Image addresses:
    sau2  0x00E0E4DA  NET_IO_$PUT_IN_SOCK_INT

  - NET_IO_$PUT_IN_SOCK with int_level true, the worker queueing with
    SOCK_$PUT_INT and handing back the socket's eventcount.
  - The result is the worker's: true when the packet was queued.

  Status stored: none.
}

function net_io_$put_in_sock_int(net_type: integer; socket: pinteger;
                                 var hdr_va: integer32;
                                 in data_pa: univ pkt_$data_pages_t;
                                 hdr_len: pinteger; data_len: pinteger;
                                 out ec_ret: ec_$eventcount_ptr_t): boolean;
  options(val_param);
begin
  net_io_$put_in_sock_int :=
    net_io_$put_in_sock_common(nil, net_type, socket, true, hdr_va,
                               data_pa, hdr_len, data_len, ec_ret);
end;
