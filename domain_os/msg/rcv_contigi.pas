{ MSG_$RCV_CONTIGI - receive a message into one buffer, the template
  and the data after it.

  Image addresses:
    sau2  0x00E597A6  MSG_$RCV_CONTIGI

  - msg_$$rcv_internal's steps inline: the template, no longer than the
    maximum, at the buffer's front, the data after it, no longer than
    the maximum and the room left; the length is the two together.
  - The dump is given the whole data length, not the copied one.

  Status stored:
    app_$receive's status: the socket is good
    status_$msg_socket_out_of_range: a socket outside 1..224
    status_$msg_no_owner: the caller does not own it
}

procedure msg_$rcv_contigi(in socket: integer;
                           out dest_net: integer32;
                           out dest_node: linteger;
                           out dest_sock: pinteger;
                           out src_net: integer32;
                           out src_node: linteger;
                           out src_sock: pinteger;
                           out hw_addr: msg_$hw_addr_t;
                           out msg_type: pinteger;
                           out data_buf: univ pkt_$bytes_t;
                           in max_len: pinteger;
                           out data_len: pinteger;
                           out status_ret: status_$t);
var
  tpl: msg_$inet_addr_ptr_t;
  rec: app_$receive_rec_t;
  reply: msg_$reply_hdr_ptr_t;
  hdr_va: integer32;
  avail: integer32;
  ptype: pinteger;
  psub: pinteger;
  n: pinteger;
  m: pinteger;
begin
  if (socket <= 0) or else (socket > msg_max_socket) then begin
    status_ret.all := status_$msg_socket_out_of_range;
    return;
  end;
  if not (proc1_$as_id in msg_$ownership[socket].owners) then begin
    status_ret.all := status_$msg_no_owner;
    return;
  end;

  app_$receive(socket, rec, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { the addresses }
  tpl := msg_$inet_addr_ptr_t(rec.data);
  reply := msg_$reply_hdr_ptr_t(rec.reply);
  dest_net := rec.hdr_f06;
  src_net := rec.hdr_f12;
  dest_node := reply^.dest_node;
  dest_sock := reply^.dest_sock;
  src_node := reply^.src_node;
  src_sock := reply^.src_sock;
  msg_type := reply^.request_id;

  { the protocol record }
  hw_addr.proto_family := reply^.proto_family;
  hw_addr.flags := rec.net_type;
  psub := reply^.proto_subtype;
  hw_addr.proto_subtype := psub;
  ptype := reply^.proto_type;
  hw_addr.proto_type := ptype;
  hw_addr.reserved2 := 0;
  hw_addr.reserved3 := 16#FFFF;
  if (ptype = msg_proto_type_inet)
     and then (psub = msg_proto_subtype_inet) then begin
    hw_addr.inet_addr := tpl^;
    reply^.template_len := reply^.template_len - 16;
    rec.data := rec.data + 16;
  end;

  { the template }
  n := min(reply^.template_len, max_len);
  data_len := n;
  os_$data_copy(pkt_$bytes_ptr_t(rec.data)^, data_buf, n);

  { the data after it }
  if rec.data_pages[1] <> 0 then begin
    m := min(reply^.data_len, max_len);
    avail := min(max_len - n, m);
    pkt_$dat_copy(rec.data_pages, avail,
                  integer32(addr(data_buf[data_len + 1])));
    pkt_$dump_data(rec.data_pages, reply^.data_len);
    data_len := data_len + avail;
  end;

  hdr_va := rec.data & (-16#400);
  netbuf_$rtn_hdr(hdr_va);
end;
