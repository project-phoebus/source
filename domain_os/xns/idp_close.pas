{ XNS_IDP_$CLOSE - close an IDP channel (the user's call).

  Image addresses:
    sau2  0x00E189C4  XNS_IDP_$CLOSE

  - Under the module's lock the channel's user socket is closed and
    forgotten; XNS_IDP_$OS_CLOSE then closes the channel.

  Status stored:
    xns_idp_$os_close's status: the channel was closed, or not
    status_$xns_bad_channel (16#3B0004): an index of 16 or more, a free
      channel, or another address space's
}

procedure xns_idp_$close(in channel: pinteger; out status: status_$t);
var
  close_status: status_$t;
begin
  status.all := status_$ok;
  ml_$exclusion_start(xns_idp_$lock);

  if (channel >= xns_max_channels)
     or else not (xns_chan_state_active in xns_idp_$channels[channel].state)
     or else (xns_idp_$channels[channel].flags.owner <> proc1_$as_id) then
  begin
    ml_$exclusion_stop(xns_idp_$lock);
    status.all := status_$xns_bad_channel;
    return;
  end;

  with xns_idp_$channels[channel] do begin
    if user_socket <> xns_no_socket then
      sock_$close(user_socket);
    user_socket := xns_no_socket;
  end;

  ml_$exclusion_stop(xns_idp_$lock);
  xns_idp_$os_close(channel, close_status);
  status := close_status;
end;
