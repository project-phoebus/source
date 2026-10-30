{ XNS_IDP_$RECEIVE - take the next packet of a channel's user socket
  into the caller's buffers.

  Image addresses:
    sau2  0x00E18CE2  XNS_IDP_$RECEIVE
    sau2  0x00E18C5E  xns_$copy_packet_data (nested)

  - A channel that builds its headers gives the caller the packet's two
    addresses and type; the MAC source always.
  - Under a cleanup handler the header and the data go into the caller's
    buffer chain (the nested xns_$copy_packet_data), the last buffer
    shortened to what it got and every later one emptied.
  - The packet's buffers are given back in every case.

  Status stored:
    status_$ok: the packet was received
    status_$xns_bad_channel (16#3B0004): an index of 16 or more, a free
      channel, or another address space's (unless open flag member 15)
    status_$xns_no_socket (16#3B0005): the channel has no user socket
    status_$xns_no_data (16#3B0006): the socket is empty
    status_$xns_illegal_buffer_spec (16#3B0008): no first address, or a
      negative length or one with no address
    status_$xns_buffer_too_small (16#3B0007): no room for the packet
    netbuf_$getva's status: the data page could not be mapped
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 14 frame bytes of XNS_IDP_$RECEIVE no object explains

  With info, cleanup_rec and cur at the image's places and head's and
  capacity's slots below cur, the SAU2 frame needs 8 bytes above
  data_va (the stand-ins unused_68 and unused_6c, two longwords: an
  8-byte object would be placed at a multiple of 8 from A6, where these
  bytes do not start), and partial leaves 6 above the
  `with''s temporary (unused_7c). }

procedure xns_idp_$receive(in channel: pinteger;
                           in out rec: xns_$idp_recv_t;
                           out status: status_$t);
label
  10;
var
  info: sock_$pkt_info_t;
  cleanup_rec: fim_$cleanup_rec_t;
  cur: mac_os_$buf_desc_ptr_t;
  head: mac_os_$buf_desc_ptr_t;
  capacity: integer32;
  unused_68: integer32;                   { stand-in }
  unused_6c: integer32;
  data_va: integer32;
  cleanup_status: status_$t;
  partial: integer;
  unused_7c: array[1..3] of integer;      { stand-in }

  { xns_$copy_packet_data - copy bytes into the caller's buffer chain.

    - length bytes go into the chain from the current buffer on, from
      partial bytes into it; a partly filled buffer stays current.

    Status stored: none.
  }

  procedure xns_$copy_packet_data(var src_cell: integer32; length: integer);
  var
    dst_va: integer32;                    { stored from D1 }
    src_va: integer32;
    remaining: integer;
    chunk: integer;
  begin
    src_va := src_cell;
    remaining := length;

    while (remaining <> 0) and then (cur <> nil) do begin
      chunk := remaining;
      if chunk > cur^.length - partial then
        chunk := cur^.length - partial;
      dst_va := partial + cur^.address;
      os_$data_copy(pkt_$bytes_ptr_t(src_va)^, pkt_$bytes_ptr_t(dst_va)^,
                    chunk);
      src_va := src_va + chunk;
      remaining := remaining - chunk;
      if remaining = 0 then
        partial := partial + chunk
      else begin
        partial := 0;
        cur := cur^.next;
      end;
    end;
  end;

begin
  status.all := status_$ok;
  data_va := 0;
  if (channel >= xns_max_channels)
     or else not (xns_chan_state_active in xns_idp_$channels[channel].state)
     or else (not (15 in xns_idp_$channels[channel].flags.members)
              and then (xns_idp_$channels[channel].flags.owner
                        <> proc1_$as_id)) then begin
    status.all := status_$xns_bad_channel;
    return;
  end;

  with xns_idp_$channels[channel] do begin
    if user_socket = xns_no_socket then begin
      status.all := status_$xns_no_socket;
      return;
    end;
    if not sock_$get(user_socket, info) then begin
      status.all := status_$xns_no_data;
      return;
    end;
    if xns_chan_flag_build_header in flags.members then begin
      rec.addrs := xns_$idp_header_ptr_t(info.hdr)^.addrs;
      rec.packet_type := xns_$idp_header_ptr_t(info.hdr)^.packet_type;
    end;
  end;

  rec.mac_src_hi := info.src_addr;
  rec.mac_src_lo := info.src_port;

  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    if rec.iov.address = 0 then begin
      status.all := status_$xns_illegal_buffer_spec;
      goto 10;
    end;
    head := addr(rec.iov);
    cur := head;
    capacity := 0;
    while cur <> nil do begin
      if (cur^.length < 0)
         or else ((cur^.length > 0) and then (cur^.address = 0)) then begin
        status.all := status_$xns_illegal_buffer_spec;
        goto 10;
      end;
      capacity := capacity + cur^.length;
      cur := cur^.next;
    end;

    if info.hdr_len + info.data_len > capacity then begin
      status.all := status_$xns_buffer_too_small;
      goto 10;
    end;
    if info.data_len <> 0 then begin
      netbuf_$getva(info.data_pages[1], data_va, status);
      if status.all <> status_$ok then begin
        data_va := 0;
        goto 10;
      end;
    end;

    cur := head;
    partial := 0;
    if info.hdr_len <> 0 then
      xns_$copy_packet_data(info.hdr, info.hdr_len);
    if info.data_len <> 0 then
      xns_$copy_packet_data(data_va, info.data_len);

    if partial > 0 then begin
      cur^.length := partial;
      cur := cur^.next;
    end;
    while cur <> nil do begin
      cur^.length := 0;
      cur := cur^.next;
    end;
    status.all := status_$ok;

10:
    netbuf_$rtn_pkt(info.hdr, data_va, info.data_pages, info.data_len);
    fim_$rls_cleanup(cleanup_rec);
  end

  else begin
    netbuf_$rtn_pkt(info.hdr, data_va, info.data_pages, info.data_len);
    status := cleanup_status;
  end;
end;
