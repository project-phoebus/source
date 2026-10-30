{ NET_IO_$PUT_IN_SOCK - deliver a received packet to a socket of this
  node, at process level.

  Image addresses:
    sau2  0x00E0E4A0  NET_IO_$PUT_IN_SOCK

  - net_io_$put_in_sock_common with no port and int_level false; its
    result is not used.

  Status stored: none.
}

procedure net_io_$put_in_sock(net_type: integer; socket: pinteger;
                              var hdr_va: integer32;
                              in data_pa: univ pkt_$data_pages_t;
                              hdr_len: pinteger; data_len: pinteger);
  options(val_param);
var
  ec: ec_$eventcount_ptr_t;
begin
  discard(net_io_$put_in_sock_common(nil, net_type, socket, false, hdr_va,
                                     data_pa, hdr_len, data_len, ec));
end;
