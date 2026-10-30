{ msg_$$rcv_internal - take the next message off a socket and split it
  into the caller's template and data.

  Image addresses:
    sau2  0x00E59548  msg_$$rcv_internal

  - APP_$RECEIVE takes the packet; both ends' addresses, the message
    type and the sender's protocol record (an internet message's 16-byte
    address off the template's front) are handed back.
  - The template and data are copied, no more than the caller's maxima,
    the data pages dumped and the header given back.

  Status stored:
    app_$receive's status: always
}

procedure msg_$$rcv_internal(socket: integer;
                             out dest_net: integer32;
                             out dest_node: linteger;
                             out dest_sock: pinteger;
                             out src_net: integer32;
                             out src_node: linteger;
                             out src_sock: pinteger;
                             out hw_addr: msg_$hw_addr_t;
                             out msg_type: pinteger;
                             out template: univ pkt_$bytes_t;
                             template_max: pinteger;
                             out template_len_ret: pinteger;
                             out data: univ pkt_$bytes_t;
                             data_max: pinteger;
                             out data_len_ret: pinteger;
                             out ec_param1_ret: integer;
                             out ec_param2_ret: pinteger;
                             out status_ret: status_$t);
  internal;
var
  rec: app_$receive_rec_t;
  tpl: integer32;
  reply: msg_$reply_hdr_ptr_t;
  hdr_va: integer32;                      { held, with its home slot }
  ptype: pinteger;
  psub: pinteger;
begin
  app_$receive(socket, rec, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { the addresses }
  tpl := rec.data;
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
  ptype := reply^.proto_type;
  hw_addr.proto_type := ptype;
  psub := reply^.proto_subtype;
  hw_addr.proto_subtype := psub;
  hw_addr.reserved2 := 0;
  hw_addr.reserved3 := 16#FFFF;
  if (ptype = msg_proto_type_inet)
     and then (psub = msg_proto_subtype_inet) then begin
    hw_addr.inet_addr := msg_$inet_addr_ptr_t(tpl)^;
    reply^.template_len := reply^.template_len - 16;
    rec.data := rec.data + 16;
  end;

  { the template and the header page's words }
  template_max := min(template_max, reply^.template_len);
  template_len_ret := template_max;
  os_$data_copy(pkt_$bytes_ptr_t(rec.data)^, template, template_max);
  hdr_va := rec.data & (-16#400);
  ec_param1_ret := netbuf_$hdr_page_ptr_t(hdr_va)^.ec_param1;
  ec_param2_ret := netbuf_$hdr_page_ptr_t(hdr_va)^.ec_param2;

  { the data }
  if rec.data_pages[1] = 0 then
    data_len_ret := 0
  else begin
    data_max := min(data_max, reply^.data_len);
    data_len_ret := data_max;
    pkt_$dat_copy(rec.data_pages, data_max, integer32(addr(data)));
    pkt_$dump_data(rec.data_pages, reply^.data_len);
  end;

  netbuf_$rtn_hdr(hdr_va);
end;
