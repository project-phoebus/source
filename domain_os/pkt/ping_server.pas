{ PKT_$PING_SERVER - the ping server process.

  Image addresses:
    sau2  0x00E12BB8  PKT_$PING_SERVER

  - The ping socket (13) is opened (a failure crashes the system) and
    ml_$ping_server_lock taken.
  - Forever, each request is answered with its flags (bits 7 and 4
    cleared, 5 set) and PKT's 2-byte template.
  - Up to two bytes of the request's template go into a buffer nothing
    reads.

  Status stored: none.
}

{ TODO(pascal) 22 frame bytes of PKT_$PING_SERVER hold nothing

  The addressed locals, the three register-held ones' slots and the
  temporary (template_buf's address) leave 22 bytes of the frame that
  no instruction addresses, held by stand-ins.  The locals one might
  declare (an opened flag, a request header) are register values or
  none.  Not settled; compare PKT_$LIKELY_TO_ANSWER's
  (pkt/likely_to_answer.pas). }

procedure pkt_$ping_server;
var
  wait_val: integer32;
  recv: app_$receive_rec_t;
  tpl_len: pinteger;
  flags: pinteger;
  unused_40: array[1..12] of char;        { stand-in }
  hdr_page: integer32;
  status: status_$t;
  dest_node: integer32;
  routing_key: integer32;
  unused_56: array[1..6] of char;         { stand-in }
  resp_timeout: pinteger;
  retry_hint: integer;
  data_len: integer;
  template_buf: array[1..4] of char;
  request_id: pinteger;
  dest_sock: pinteger;
  unused_68: integer32;                   { stand-in }
begin
  if not sock_$open(13, 3, 0, 0, 1024) then
    crash_system(status_$network_no_more_free_sockets);
  proc1_$set_lock(ml_$ping_server_lock);

  wait_val := sock_$socket_ptr[13]^.ec.value + 1;

  { the requests }
  repeat
    discard(ec_$wait(addr(sock_$socket_ptr[13]^.ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), wait_val, 1, 1));
    app_$receive(13, recv, status);
    if status.all <> status_$ok then
      next;

    { the request taken in }
    routing_key := recv.hdr_f12;
    data_len := pkt_$internet_hdr_ptr_t(recv.reply)^.data_len;
    dest_node := pkt_$internet_hdr_ptr_t(recv.reply)^.src_node;
    dest_sock := pkt_$internet_hdr_ptr_t(recv.reply)^.src_sock;
    flags := pkt_$internet_hdr_ptr_t(recv.reply)^.flags;
    request_id := pkt_$internet_hdr_ptr_t(recv.reply)^.request_id;
    tpl_len := min(2, pkt_$internet_hdr_ptr_t(recv.reply)^.hdr_len);
    os_$data_copy(pkt_$bytes_ptr_t(recv.data)^, template_buf, tpl_len);
    hdr_page := recv.data & (-16#400);
    netbuf_$rtn_hdr(hdr_page);
    if recv.data_pages[1] <> 0 then
      pkt_$dump_data(recv.data_pages, data_len);

    { the reply }
    pkt_$ping_reply_info.flags := (flags & 16#FF6F) ! 16#20;
    pkt_$send_internet(routing_key, dest_node, dest_sock, -1, node_$me,
                       13, pkt_$ping_reply_info, request_id,
                       pkt_$ping_req_hdr, 2, 0, 0, retry_hint,
                       resp_timeout, status);
    wait_val := wait_val + 1;
  until false;
end;
