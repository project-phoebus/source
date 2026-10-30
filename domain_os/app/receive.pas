{ APP_$RECEIVE - take the next packet off a socket and describe it.

  Image addresses:
    sau2  0x00E00800  APP_$RECEIVE

  - The payload pages, the queue depth and the source go into the
    caller's record; the reply is built for an XNS packet (a zero source
    network taken from its port) or a Domain internet one.
  - A reply that would not fit is built over the received header, the
    header copied to the module's buffer under its exclusion lock.

  Status stored:
    status_$ok: a packet was taken
    status_$network_buffer_queue_is_empty: the socket had none
}

{ TODO(pascal) 24 frame bytes that nothing addresses

  The SAU2 image's frame holds info, bounce and the five register-held
  locals' slots; 24 bytes are not explained: no instruction addresses
  them, and the image's other values are temporaries of one statement.
  Locals of the original that the image keeps in registers or `with'
  temporaries with frame slots of their own (three `with's here would be
  12 bytes) could account for them.  Stand-in `unused_68'. }

{ TODO(pascal) bounce's store between OS_$DATA_COPY's pushes

  The SAU2 image stores bounce := addr(temp_buffer) after the call's
  first push (the third argument, hdr_off) and pushes the second
  argument through the register just stored.  The source here assigns
  bounce in the statement before the call, which would store before the
  first push.  An assignment inside the argument list is not Pascal; a
  scheduler moving the push above the previous statement's store is not
  a known form for pushes. }

procedure app_$receive(sock_num: pinteger; out rec: app_$receive_rec_t;
                       out status: status_$t);
var
  info: sock_$pkt_info_t;
  holding_lock: boolean;
  hdr: app_$rcv_hdr_ptr_t;
  hdr_off: integer32;
  rounded: pinteger;
  net_type: 0..255;
  unused_68: array[1..6] of integer32;    { see the TODO }
  bounce: app_$rcv_hdr_ptr_t;
begin
  status.all := status_$ok;
  holding_lock := false;

  if not sock_$get(sock_num, info) then begin
    status.all := status_$network_buffer_queue_is_empty;
    return;
  end;

  rec.data_pages := info.data_pages;

  rec.queue_count := sock_$socket_ptr[sock_num]^.queue_count;

  rec.src_addr := info.src_addr;
  rec.src_port := info.src_port;

  { XNS routing }
  if sock_pkt_flag_xns in info.flags then begin
    rec.hdr_flag := sock_pkt_flag_demux_bool in info.flags;

    rec.reply := info.hdr + xns_idp_header_size;
    rec.data := rec.reply + 16#18;

    with xns_$idp_header_ptr_t(info.hdr)^ do begin
      rec.hdr_f06 := dest_network;
      rec.hdr_f12 := src_network;
    end;

    rec.net_type := app_$net_type_remote;

    if rec.hdr_f12 = 0 then
      with netbuf_$hdr_page_ptr_t(info.hdr & (-16#400))^ do
        rec.hdr_f12 := route_$find_portp(ec_param1, ec_param2)^.network;

    return;
  end;

  { Domain internet routing }
  hdr := app_$rcv_hdr_ptr_t(info.hdr);
  rec.hdr_flag := 3 in hdr^.rh_flags_07;

  hdr_off := hdr^.rh_hdr_size + 30;
  rounded := (hdr_off + hdr^.rh_template_len + 3) & (-4);
  rec.data := hdr_off + integer32(hdr);

  if rounded + 24 < app_max_inline_size then
    rec.reply := rounded + integer32(hdr)
  else begin
    ml_$exclusion_start(exclusion_lock);
    holding_lock := true;
    bounce := addr(temp_buffer);
    os_$data_copy(hdr^, bounce^, hdr_off);
    rec.reply := integer32(hdr);
    hdr := bounce;
  end;

  with app_$pkt_hdr_ptr_t(rec.reply)^, hdr^ do begin
    p_magic := app_reply_magic;
    p_net_type := rh_proto_0e;
    rec.net_type := rh_net_type;
    p_request_id := rh_request_id;
    p_data_len := info.data_len;
    p_template_len := rh_template_len;

    { a local network }
    net_type := rh_net_type;
    if net_type = app_$net_type_local then begin
      rec.hdr_f06 := 0;
      rec.hdr_f12 := 0;
      p_src_node := node_$me;
      p_src_sock := rh_var[rh_sock_index];
      if rh_hdr_size = 4 then begin
        p_dest_sock := rh_sock_1a;
        p_dest_node := rh_node_08;
      end
      else begin
        p_dest_sock := rh_var[0];
        p_dest_node := rh_node_20;
      end;
    end;

    { a remote network }
    if net_type = app_$net_type_remote then begin
      rec.hdr_f06 := rh_net_2e;
      rec.hdr_f12 := rh_net_3a;
      p_src_node := rh_node_34 & 16#FFFFFF;
      p_src_sock := rh_sock_38;
      p_dest_node := rh_node_40 & 16#FFFFFF;
      p_dest_sock := rh_sock_44;
      if rh_addr_size = 4 then begin
        p_flags := rh_subtype_4b;
        p_addr_size := 2;
        if p_flags = 16#29 then begin
          rec.data := rec.data - 16;
          p_template_len := p_template_len + 16;
        end;
      end
      else begin
        p_addr_size := 1;
        p_flags := rh_addr_size;
      end;
    end;
  end;

  if holding_lock then
    ml_$exclusion_stop(exclusion_lock);
end;
