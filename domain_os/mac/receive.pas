{ MAC_$RECEIVE - take the next packet off a MAC channel's socket.

  Image addresses:
    sau2  0x00E0BDB0  MAC_$RECEIVE
    sau2  0x00E0BD2C  mac_$copy_to_buffers (nested)

  - The packet's local flag, link address, arrival time and frame type
    go into the caller's record.
  - Under a cleanup handler its header and data are poured into the
    caller's buffer chain (the nested mac_$copy_to_buffers).
  - The packet's buffers are returned in every case.
  - A MAC_OS fragment (mac/README.md).

  Status stored:
    status_$ok: the packet was received
    status_$mac_channel_not_open: the channel is 10 or above, not in
      use, or neither promiscuous nor the caller's
    status_$mac_no_socket_allocated: the channel has no socket
    status_$mac_no_packet_available_to_receive: the socket is empty
    status_$mac_illegal_buffer_spec: a negative length, or a length with
      no address
    status_$mac_received_packet_too_big: the chain is too small
    netbuf_$getva's status: the data page could not be mapped
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 4 frame bytes of MAC_$RECEIVE hold nothing the code
  addresses

  The stand-in unused_78 holds their place.  In the SAU2 frame the
  register locals chain_head, total and i fill their slots with
  data_va's alignment, and the `with' temporary takes the lowest; one
  longword remains.  Two word locals for the header and data lengths,
  which the image never keeps (each use reads the record), would fit
  instead.  Not settled. }

procedure mac_$receive(in channel: pinteger;
                       in out pkt_desc: mac_$recv_pkt_t;
                       out status: status_$t);
label
  release;
var
  pkt_info: sock_$pkt_info_t;
  cleanup_rec: fim_$cleanup_rec_t;
  cur_buf: mac_os_$buf_desc_ptr_t;
  chain_head: mac_os_$buf_desc_ptr_t;
  total: integer32;
  i: integer;
  data_va: integer32;
  cleanup_status: status_$t;
  buf_offset: integer;
  unused_78: integer32;                   { TODO above }

  { mac_$copy_to_buffers - pour length bytes from a source address into
    the parent's buffer chain.

    - The bytes go to cur_buf from buf_offset on, a buffer at a time,
      the parent's cur_buf and buf_offset following, until the bytes or
      the chain are done.

    Status stored: none.
  }

  procedure mac_$copy_to_buffers(var src_va: integer32; length: integer);
  type
    data_ptr_t = ^os_$data_t;
  var
    dest: integer32;
    src: integer32;
    remaining: integer;
    chunk: integer;
  begin
    src := src_va;
    remaining := length;

    while (remaining <> 0) and then (cur_buf <> nil) do begin
      chunk := remaining;
      if chunk > cur_buf^.length - buf_offset then
        chunk := cur_buf^.length - buf_offset;
      dest := buf_offset + cur_buf^.address;
      os_$data_copy(data_ptr_t(src)^, data_ptr_t(dest)^, chunk);
      src := src + chunk;
      remaining := remaining - chunk;
      if remaining = 0 then
        buf_offset := buf_offset + chunk
      else begin
        buf_offset := 0;
        cur_buf := cur_buf^.next;
      end;
    end;
  end;

begin
  status.all := status_$ok;
  data_va := 0;

  { the channel, its socket, the packet }
  if channel >= mac_max_channels then begin
    status.all := status_$mac_channel_not_open;
    return;
  end;
  with mac_os_$channel_table[channel] do begin
    if not (mac_os_channel_in_use in flags) then begin
      status.all := status_$mac_channel_not_open;
      return;
    end;
    if not (mac_os_channel_promiscuous in flags) then
      if bits.owner <> proc1_$as_id then begin
        status.all := status_$mac_channel_not_open;
        return;
      end;
    if socket = mac_os_no_socket then begin
      status.all := status_$mac_no_socket_allocated;
      return;
    end;
    if not sock_$get(socket, pkt_info) then begin
      status.all := status_$mac_no_packet_available_to_receive;
      return;
    end;
  end;

  { the packet's description }
  pkt_desc.is_local := sock_pkt_flag_local in pkt_info.flags;
  pkt_desc.link_addr.n_words := pkt_info.n_hops;
  for i := 0 to pkt_desc.link_addr.n_words - 1 do
    pkt_desc.link_addr.addr[i] := pkt_info.hops[i];
  pkt_desc.time.high := pkt_info.src_addr;
  pkt_desc.time.low := pkt_info.src_port;
  pkt_desc.frame_type := pkt_info.dst_addr;

  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin

    { the caller's chain }
    chain_head := addr(pkt_desc.buffers);
    cur_buf := chain_head;
    total := 0;
    while cur_buf <> nil do begin
      if (cur_buf^.length < 0)
         or else ((cur_buf^.length > 0) and then (cur_buf^.address = 0))
      then begin
        status.all := status_$mac_illegal_buffer_spec;
        goto release;
      end;
      total := total + cur_buf^.length;
      cur_buf := cur_buf^.next;
    end;

    if pkt_info.hdr_len + pkt_info.data_len > total then begin
      status.all := status_$mac_received_packet_too_big;
      goto release;
    end;

    { the data page }
    if pkt_info.data_len <> 0 then begin
      netbuf_$getva(pkt_info.data_pages[1], data_va, status);
      if status.all <> status_$ok then begin
        data_va := 0;
        goto release;
      end;
    end;

    { the header and the data }
    cur_buf := chain_head;
    buf_offset := 0;
    if pkt_info.hdr_len <> 0 then
      mac_$copy_to_buffers(pkt_info.hdr, pkt_info.hdr_len);
    if pkt_info.data_len <> 0 then
      mac_$copy_to_buffers(data_va, pkt_info.data_len);

    { the lengths written }
    if buf_offset > 0 then begin
      cur_buf^.length := buf_offset;
      cur_buf := cur_buf^.next;                     { merged }
    end;
    while cur_buf <> nil do begin
      cur_buf^.length := 0;
      cur_buf := cur_buf^.next;
    end;
    status.all := status_$ok;

  release:
    netbuf_$rtn_pkt(pkt_info.hdr, data_va, pkt_info.data_pages,
                    pkt_info.data_len);
    fim_$rls_cleanup(cleanup_rec);
  end
  else begin
    netbuf_$rtn_pkt(pkt_info.hdr, data_va, pkt_info.data_pages,
                    pkt_info.data_len);
    status := cleanup_status;
  end;
end;
