{ network_$wait_response - wait for the reply to request `pkt_id'.

  Image addresses:
    sau2  0x00E0F746  network_$wait_response (module-local)
    sau8  0x03C10A7C  network_$wait_response (module-local)

  - The wait is on the socket's eventcount and the clock (to the time
    out past now); the clock ends it with false.
  - Each packet received gives back its data length, up to 184 bytes
    of its template and its four data pages.  A reply to this request
    ends the wait with true; another's pages are dumped.

  Status stored: none.
}

{ TODO(pascal) network_$wait_response's frame

  The frame (0x4C bytes): the reserved slot, rec (0x2C), hdr, deadline,
  status and the socket element's address at the bottom (a compiler
  temporary).  Not addressed: 12 bytes above the temporary; len,
  reply_id and the `with' pointer are the candidates, not proven. }

function network_$wait_response(sock_num: integer; pkt_id: integer;
                                timeout: pinteger;
                                in out event_count: integer32;
                                out resp_buf: univ os_$data_t;
                                out resp_len_out: integer;
                                out data_bufs: pkt_$data_pages_t;
                                out data_len_out: pinteger): boolean;
  internal;
var
  rec: app_$receive_rec_t;
  hdr: integer32;
  deadline: integer32;
  status: status_$t;
  len: integer;
  reply_id: pinteger;
begin
  network_$wait_response := true;
  data_bufs[1] := 0;
  deadline := timeout + time_$clockh;

  repeat
    if ec_$wait(addr(sock_$socket_ptr[sock_num]^.ec),
                ec_$eventcount_ptr_t(addr(time_$clockh)), addr(ec_$nil_ec),
                event_count, deadline, 0) <> 0 then begin
      network_$wait_response := false;
      return;
    end;

    event_count := event_count + 1;
    app_$receive(sock_num, rec, status);
    if status.all <> status_$ok then
      next;

    with pkt_$internet_hdr_ptr_t(rec.reply)^ do begin
      data_len_out := data_len;
      len := 184;
      if hdr_len < len then
        len := hdr_len;
      resp_len_out := len;
      reply_id := request_id;
    end;

    os_$data_copy(pkt_$bytes_ptr_t(rec.data)^, resp_buf, len);
    hdr := rec.data & 16#FFFFFC00;
    netbuf_$rtn_hdr(hdr);

    data_bufs := rec.data_pages;

    if reply_id = pkt_id then
      return;
    if data_bufs[1] <> 0 then
      pkt_$dump_data(data_bufs, data_len_out);
    data_bufs[1] := 0;
  until false;
end;
