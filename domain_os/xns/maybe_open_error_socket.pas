{ MAYBE_OPEN_ERROR_SOCKET - open the error protocol's IDP channel for
  one more user.

  Image addresses:
    sau2  0x00E178AA  MAYBE_OPEN_ERROR_SOCKET

  - Under XNS_ERROR_$CLIENT_MUTEX, a channel with no users is opened on
    socket 3 with the open flag [no_alloc] and no demux routine, and its
    channel kept; the count of users goes up by one.

  Status stored:
    status_$ok: the channel was opened, or had users
    xns_idp_$os_open's status: the open failed
}

procedure maybe_open_error_socket(out status: status_$t);
label
  10;
var
  opt: xns_$os_open_opt_t;
begin
  status.all := status_$ok;
  ml_$exclusion_start(xns_error_$client_mutex);

  if client_ref_count = 0 then begin
    opt.socket := xns_socket_error;
    opt.flags := [xns_open_flag_no_alloc];
    opt.demux := nil;
    xns_idp_$os_open(opt, status);
    if status.all <> status_$ok then
      goto 10;
    xns_error_$std_idp_channel := opt.flags_channel;
  end;

  client_ref_count := client_ref_count + 1;

10:
  ml_$exclusion_stop(xns_error_$client_mutex);
end;
