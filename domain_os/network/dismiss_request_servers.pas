{ NETWORK_$DISMISS_REQUEST_SERVERS - stop the request servers.

  Image addresses:
    sau2  0x00E71E78  NETWORK_$DISMISS_REQUEST_SERVERS

  - The quit eventcount is advanced, and the request servers' done
    eventcount waited for until it reaches the number of servers, or for
    two minutes.

  Status stored: none.
}

{ TODO(pascal) the 4-byte frame of NETWORK_$DISMISS_REQUEST_SERVERS

  The frame has 4 bytes, with no local and no frame access; dpc gives
  the body frame 0.  A local assigned the discarded EC_$WAIT result (its
  store dropped as dead) would take the slot; `discard' costs
  NETWORK_$INIT nothing (its frame is its locals), so it is not the
  discard. }

[section(procedure$, data$)]
procedure network_$dismiss_request_servers;
begin
  ec_$advance(network_$rqst_quit_ec);
  discard(ec_$wait(addr(network_$rqst_done_ec), addr(time_$clockh_ec),
                   addr(ec_$nil_ec), network_$request_server_cnt,
                   time_$clockh_ec.value + 120, 0));
end;
