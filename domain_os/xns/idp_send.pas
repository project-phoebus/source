{ XNS_IDP_$SEND - send an IDP packet on a channel (the user's call).

  Image addresses:
    sau2  0x00E18A66  XNS_IDP_$SEND

  - Under a cleanup handler the kernel's request record gets the two
    addresses, the packet type, no data and the caller's header ("not
    built"), and XNS_IDP_$OS_SEND sends; its length is returned.
  - The flag byte of every later entry of the caller's chain is cleared.

  Status stored:
    xns_idp_$os_send's status: the packet was sent, or not
    status_$xns_bad_channel (16#3B0004): an index of 16 or more, a free
      channel or another address space's
    status_$xns_illegal_buffer_spec (16#3B0008): a header buffer with no
      address or fewer than 30 bytes
    the fault's status: a fault unwound to the handler
}

{ TODO(pascal) 4 frame bytes of XNS_IDP_$SEND no object explains

  Below the locals in the order declared, one longword of the SAU2 frame
  holds no object the code addresses (the stand-in unused_74).  The
  routine has no `with'; XNS_IDP_$CLOSE, with the same channel test and
  a `with', has no open byte (xns/idp_close.pas). }

procedure xns_idp_$send(in channel: pinteger; in rec: xns_$idp_send_t;
                        out len_sent: integer; out status: status_$t);
var
  os_rec: xns_$os_send_rec_t;
  cleanup_rec: fim_$cleanup_rec_t;
  entry: mac_os_$buf_entry_ptr_t;
  os_status: status_$t;
  cleanup_status: status_$t;
  os_len: integer;
  unused_74: integer32;                   { stand-in }
begin
  len_sent := 0;
  status.all := status_$ok;

  if (channel >= xns_max_channels)
     or else not (xns_chan_state_active in xns_idp_$channels[channel].state)
     or else (xns_idp_$channels[channel].flags.owner <> proc1_$as_id) then
  begin
    status.all := status_$xns_bad_channel;
    return;
  end;

  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    if (rec.hdr_desc.address = 0)
       or else (rec.hdr_desc.length < xns_idp_header_size) then begin
      fim_$rls_cleanup(cleanup_rec);
      status.all := status_$xns_illegal_buffer_spec;
      return;
    end;

    os_rec.addrs := rec.addrs;
    os_rec.packet_type := rec.packet_type;
    os_rec.data.length := 0;
    os_rec.data.pages[1] := 0;
    os_rec.hdr_desc := rec.hdr_desc;
    os_rec.hdr_prebuilt := false;
    entry := mac_os_$buf_entry_ptr_t(rec.hdr_desc.next);
    while entry <> nil do begin
      entry^.flag_0c := false;
      entry := mac_os_$buf_entry_ptr_t(entry^.desc.next);
    end;

    xns_idp_$os_send(channel, os_rec, os_len, os_status);
    len_sent := os_len;
    status := os_status;
    fim_$rls_cleanup(cleanup_rec);
  end

  else
    status := cleanup_status;
end;
