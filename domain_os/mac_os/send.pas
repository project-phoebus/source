{ MAC_OS_$SEND - send a packet on a channel at the MAC_OS level.

  Image addresses:
    sau2  0x00E0B5A8  MAC_OS_$SEND
    sau2  0x00E0B522  mac_os_$copy_buffer_data (nested)

  - Under a cleanup handler, a header not built yet is built: the
    caller's buffer chain (at most 1976 bytes) is copied into a header
    page and a data page (the nested mac_os_$copy_buffer_data).
  - The packet record is rewritten to describe them.
  - The driver's send entry sends it; the buffers are given back.

  Status stored:
    the driver's send entry's status: the packet was sent, or not
    status_$mac_port_op_not_implemented (16#3A0001): no send entry
    status_$mac_illegal_buffer_spec (16#3A000C): a negative length, a
      length with no address, or too many bytes
    netbuf_$getva's status: a data page could not be mapped
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) four frame bytes of MAC_OS_$SEND hold nothing

  The stand-in unused_42 holds the 4 bytes between total_length and
  needs_buffers (both addressed); no instruction addresses them.  No
  further local would sit there; the driver and its send entry are
  reached through the channel each time.  Not settled. }

procedure mac_os_$send(in channel: pinteger;
                       in out pkt: mac_os_$send_pkt_t;
                       out bytes_sent: integer;
                       out status: status_$t);
label
  send_done;
var
  cleanup_rec: fim_$cleanup_rec_t;
  copy_chain: mac_os_$buf_desc_ptr_t;
  cleanup_status: status_$t;
  buffer_status: status_$t;
  data_ptr: integer32;
  header_ptr: integer32;
  data_page: integer32;
  header_phys: integer32;
  copy_offset: integer;
  header_length: integer;
  use_header_buf: boolean;
  use_data_buf: boolean;
  total_length: integer;
  unused_42: integer32;                   { stand-in: TODO above }
  needs_buffers: boolean;

  { mac_os_$copy_buffer_data - copy length bytes from the parent's
    buffer chain to an address.

    - The bytes come from copy_chain's buffer from copy_offset on, a
      buffer at a time, the parent's copy_chain and copy_offset
      following, until the bytes or the chain are done.

    Status stored: none.
  }

  procedure mac_os_$copy_buffer_data(var dest_va: integer32;
                                     length: integer);
  type
    data_ptr_t = ^os_$data_t;
  var
    dst: integer32;
    src: integer32;
    remaining: integer;
    chunk: integer;
  begin
    dst := dest_va;
    remaining := length;

    while (remaining <> 0) and then (copy_chain <> nil) do begin
      chunk := remaining;
      if chunk > copy_chain^.length - copy_offset then
        chunk := copy_chain^.length - copy_offset;
      src := copy_offset + copy_chain^.address;
      os_$data_copy(data_ptr_t(src)^, data_ptr_t(dst)^, chunk);
      dst := dst + chunk;
      remaining := remaining - chunk;
      if remaining = 0 then
        copy_offset := copy_offset + chunk
      else begin
        copy_offset := 0;
        copy_chain := copy_chain^.next;
      end;
    end;
  end;

begin
  bytes_sent := 0;
  status.all := status_$ok;
  header_ptr := 0;
  data_ptr := 0;

  with mac_os_$channel_table[channel] do begin
    if net_io_$driver_ptr_t(driver_info)^.send_os = nil then begin
      status.all := status_$mac_port_op_not_implemented;
      return;
    end;

    cleanup_status := fim_$cleanup(cleanup_rec);
    if cleanup_status.all = fault_$cleanup_set then begin
      needs_buffers := not pkt.hdr_prebuilt;
      if needs_buffers then begin
        { the caller's chain checked }
        use_header_buf := true;
        use_data_buf := true;
        copy_chain := addr(pkt.hdr_desc);
        total_length := 0;
        while copy_chain <> nil do begin
          if copy_chain^.length < 0 then begin
            fim_$rls_cleanup(cleanup_rec);
            status.all := status_$mac_illegal_buffer_spec;
            return;
          end;
          if (copy_chain^.length > 0)
             and then (copy_chain^.address = 0) then begin
            fim_$rls_cleanup(cleanup_rec);
            status.all := status_$mac_illegal_buffer_spec;
            return;
          end;
          total_length := total_length + copy_chain^.length;
          copy_chain := copy_chain^.next;
        end;
        if total_length > mac_os_max_packet_size then begin
          fim_$rls_cleanup(cleanup_rec);
          status.all := status_$mac_illegal_buffer_spec;
          return;
        end;

        { the buffers the length needs }
        if total_length = 0 then begin
          use_header_buf := false;
          use_data_buf := false;
        end
        else if total_length <= mac_os_small_packet_size then
          use_data_buf := false
        else if total_length <= mac_os_large_packet_size then
          use_header_buf := false;

        copy_chain := addr(pkt.hdr_desc);
        copy_offset := 0;
        header_length := 0;
        netbuf_$get_hdr(header_phys, header_ptr);
        header_ptr := header_ptr + header_size;

        { the header buffer }
        if use_header_buf then begin
          if use_data_buf then begin
            header_length := total_length - mac_os_large_packet_size;
            total_length := mac_os_large_packet_size;
          end
          else begin
            header_length := total_length;
            total_length := 0;
          end;
          mac_os_$copy_buffer_data(header_ptr, header_length);
        end;

        { the data buffer }
        if use_data_buf then begin
          netbuf_$get_dat(data_page);
          netbuf_$getva(data_page, data_ptr, buffer_status);
          if buffer_status.all <> status_$ok then begin
            status := buffer_status;
            data_ptr := 0;
            goto send_done;
          end;
          pkt.data_pages[1] := data_page;
          mac_os_$copy_buffer_data(data_ptr, total_length);
          discard(netbuf_$rtnva(data_ptr));
          data_ptr := 0;
        end
        else
          pkt.data_pages[1] := 0;

        { the record describes the buffers }
        pkt.hdr_desc.length := header_length;
        pkt.hdr_desc.address := header_ptr;
        pkt.hdr_desc.next := nil;
        pkt.data_length := total_length;
      end;

      mac_os_$drv_send_t(net_io_$driver_ptr_t(driver_info)^.send_os)^(
        line_number, callback_data, pkt, bytes_sent, status);

    send_done:
      if needs_buffers then
        netbuf_$rtn_pkt(header_ptr, data_ptr, pkt.data_pages, total_length);
      fim_$rls_cleanup(cleanup_rec);
    end
    else begin
      { a fault unwound to the handler }
      if needs_buffers then
        netbuf_$rtn_pkt(header_ptr, data_ptr, pkt.data_pages, total_length);
      status := cleanup_status;
    end;
  end;
end;
