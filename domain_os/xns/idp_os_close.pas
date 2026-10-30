{ XNS_IDP_$OS_CLOSE - close an IDP channel (the OS's call).

  Image addresses:
    sau2  0x00E181D8  XNS_IDP_$OS_CLOSE

  - Under the module's lock one channel fewer is open; the channel is
    unbound from every port it is active on and freed.

  Status stored:
    status_$ok: the channel was closed
    xns_$delete_port's status: an unbind failed
}

{ TODO(pascal) 4 frame bytes of XNS_IDP_$OS_CLOSE no object explains

  In the SAU2 frame p's slot and the `with''s temporary leave one
  longword to the stand-in unused_8. }

procedure xns_idp_$os_close(in channel: pinteger; out status: status_$t);
var
  p: integer;
  unused_8: integer32;                    { stand-in }
begin
  status.all := status_$ok;
  ml_$exclusion_start(xns_idp_$lock);
  xns_idp_$open_channels := xns_idp_$open_channels - 1;

  with xns_idp_$channels[channel] do begin
    for p := 0 to xns_max_ports - 1 do
      if port_active[p] then
        xns_$delete_port(channel, p, status);
    state := state - [xns_chan_state_active];
    flags.open_flags := 0;
    xns_socket := 0;
    demux := nil;
  end;

  ml_$exclusion_stop(xns_idp_$lock);
end;
