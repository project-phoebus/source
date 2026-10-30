{ MAC_$CLOSE - close a MAC channel.

  Image addresses:
    sau2  0x00E0BA6C  MAC_$CLOSE

  - Under the MAC_OS exclusion lock the channel's socket is closed if it
    has one; then MAC_OS_$CLOSE releases the channel.
  - A MAC_OS fragment (mac/README.md).

  Status stored:
    mac_os_$close's status: the channel was closed, or not
    status_$mac_channel_not_open: the channel is 10 or above, not in
      use, or another address space's
}

procedure mac_$close(in channel: pinteger; out status: status_$t);
var
  local_status: status_$t;
begin
  status.all := status_$ok;
  ml_$exclusion_start(mac_os_$exclusion);

  { the merged failure blocks }
  if channel >= mac_max_channels then begin
    ml_$exclusion_stop(mac_os_$exclusion);
    status.all := status_$mac_channel_not_open;
    return;
  end;
  with mac_os_$channel_table[channel] do begin
    if not (mac_os_channel_in_use in flags) then begin
      ml_$exclusion_stop(mac_os_$exclusion);
      status.all := status_$mac_channel_not_open;
      return;
    end;
    if bits.owner <> proc1_$as_id then begin
      ml_$exclusion_stop(mac_os_$exclusion);
      status.all := status_$mac_channel_not_open;
      return;
    end;

    if socket <> mac_os_no_socket then
      sock_$close(socket);
    socket := mac_os_no_socket;
  end;

  ml_$exclusion_stop(mac_os_$exclusion);
  mac_os_$close(channel, local_status);
  status := local_status;
end;
