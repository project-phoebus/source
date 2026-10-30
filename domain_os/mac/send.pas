{ MAC_$SEND - send a packet on a MAC channel.

  Image addresses:
    sau2  0x00E0BB12  MAC_$SEND

  - Under a cleanup handler: with is_broadcast, MAC_OS_$ARP fills the
    link address with the broadcast address; the record goes to
    MAC_OS_$SEND with no data and the header to be built.
  - The flag byte of every further buffer of the caller's chain is
    cleared.  The bytes sent are MAC_OS_$SEND's count.

  Status stored:
    mac_os_$send's status: the packet was sent, or not
    status_$mac_channel_not_open: the channel is 10 or above, not in
      use, or another address space's
    mac_os_$arp's status: the broadcast address could not be had
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 8 frame bytes of MAC_$SEND hold nothing the code addresses

  The stand-ins unused_6c and unused_7c hold their places.  Of the
  SAU2 frame's 0x80 bytes, two longwords are never addressed: one above
  os_status, one above the `with' temporary.  Register locals for the
  channel number, the flags, the owner and the port could account for
  them; no order of those fits the addressed offsets without the gap
  above os_status.  Not settled. }

procedure mac_$send(in channel: pinteger; in out pkt_desc: mac_$send_pkt_t;
                    out bytes_sent: integer; out status: status_$t);
label
  release;
var
  chain: mac_os_$buf_entry_ptr_t;
  local_pkt: mac_os_$send_pkt_t;
  cleanup_rec: fim_$cleanup_rec_t;
  unused_6c: integer32;                   { TODO above }
  os_status: status_$t;
  cleanup_status: status_$t;
  local_bytes_sent: integer;
  arp_broadcast: boolean;
  unused_7c: integer32;                   { TODO above }
begin
  bytes_sent := 0;
  status.all := status_$ok;

  { the merged failure blocks }
  if channel >= mac_max_channels then begin
    status.all := status_$mac_channel_not_open;
    return;
  end;
  with mac_os_$channel_table[channel] do begin
    if not (mac_os_channel_in_use in flags) then begin
      status.all := status_$mac_channel_not_open;
      return;
    end;
    if bits.owner <> proc1_$as_id then begin
      status.all := status_$mac_channel_not_open;
      return;
    end;

    cleanup_status := fim_$cleanup(cleanup_rec);
    if cleanup_status.all = fault_$cleanup_set then begin
      if pkt_desc.is_broadcast then begin
        mac_os_$arp(mac_os_$broadcast_nexthop, port_index,
                    pkt_desc.link_addr, arp_broadcast, status);
        if status.all <> status_$ok then
          goto release;
      end;

      { the record for MAC_OS_$SEND }
      local_pkt.link_addr := pkt_desc.link_addr;
      local_pkt.is_broadcast := pkt_desc.is_broadcast;
      local_pkt.frame_type := pkt_desc.frame_type;
      local_pkt.data_length := 0;
      local_pkt.data_pages[1] := 0;
      local_pkt.hdr_desc := pkt_desc.hdr_desc;
      local_pkt.hdr_prebuilt := false;

      { the caller's further buffers }
      chain := mac_os_$buf_entry_ptr_t(pkt_desc.hdr_desc.next);
      while chain <> nil do begin
        chain^.flag_0c := false;
        chain := mac_os_$buf_entry_ptr_t(chain^.desc.next);
      end;

      mac_os_$send(channel, local_pkt, local_bytes_sent, os_status);
      bytes_sent := local_bytes_sent;
      status := os_status;

    release:
      fim_$rls_cleanup(cleanup_rec);
    end
    else
      status := cleanup_status;
  end;
end;
