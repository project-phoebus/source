{ MAYBE_CLOSE_ERROR_SOCKET - give up one user of the error protocol's
  IDP channel.

  Image addresses:
    sau2  0x00E17910  MAYBE_CLOSE_ERROR_SOCKET

  - Under XNS_ERROR_$CLIENT_MUTEX the count of users goes down by one;
    at 0 the channel is closed and forgotten (16#FFFF).
  - With no users the routine returns holding XNS_ERROR_$CLIENT_MUTEX.

  Status stored: none.
}

procedure maybe_close_error_socket;
var
  close_status: status_$t;
begin
  ml_$exclusion_start(xns_error_$client_mutex);
  if client_ref_count = 0 then
    return;

  client_ref_count := client_ref_count - 1;
  if client_ref_count = 0 then begin
    xns_idp_$os_close(xns_error_$std_idp_channel, close_status);
    xns_error_$std_idp_channel := 16#FFFF;
  end;

  ml_$exclusion_stop(xns_error_$client_mutex);
end;
