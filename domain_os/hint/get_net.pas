{ HINT_$GET_NET - the network port the hint file records.

  Image addresses:
    sau2  0x00E49CC0  HINT_$GET_NET

  - The file's network, when the hint file is published, initialized
    (its version not 1) and written for port 0's type and socket; else
    0.

  Status stored: none.
}

procedure hint_$get_net(out port_ret: integer32);
var
  hintfile: hint_$file_ptr_t;
begin
  port_ret := 0;
  hintfile := hint_$hintfile_ptr;
  if (hintfile <> nil)
     and then (hintfile^.version <> 1)
     and then (hintfile^.port_type = route_$portp[0]^.port_type)
     and then (hintfile^.socket = route_$portp[0]^.socket) then
    port_ret := hintfile^.net_port;
end;
