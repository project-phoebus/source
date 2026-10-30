{ xns_$find_socket - whether an open channel has an IDP socket.

  Image addresses:
    sau2  0x00E17D12  xns_$find_socket

  - True at the first open channel whose socket is the one asked about.

  Status stored: none.
}

function xns_$find_socket(socket: pinteger): boolean; internal;
var
  i: integer;                             { the loop's }
  unused_8: integer;                      { stand-in }
begin
  xns_$find_socket := false;
  for i := 0 to xns_max_channels - 1 do
    with xns_idp_$channels[i] do
      if (xns_chan_state_active in state) and then (xns_socket = socket)
      then begin
        xns_$find_socket := true;
        return;
      end;
end;
