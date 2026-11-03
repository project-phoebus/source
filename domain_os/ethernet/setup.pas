{ ethernet_setup - set an adapter up: its memory, its station address,
  its multicast list and its receive mode.

  Image addresses:
    sau8  0x03C84EA6  ethernet_setup
    sau9  0x3C480AA6  ethernet_setup

  - A unit without a station address gets Apollo's: the vendor block
    08-00-1E and the node's number.  An address with either half zero
    crashes the system.
  - The commands are polled; the first that fails ends the setup.  The
    multicast list holds 09-00-1E-00-00-00 and 09-00-1E-00-00-01, and
    the 82586 is left in receive mode 2.

  Status stored:
    ethernet_do_cmd_polled's status: the last command's
}

{ TODO(pascal) the adapter memory command's data

  The SAU9 image copies the configure-memory command's 12 data bytes
  whole, from a constant in the code.  No Pascal form of a 12-byte
  constant assigned whole is known that gives that copy; the six words
  are assigned one by one here, the same bytes. }

procedure ethernet_setup(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
begin
  if (u^.station.high = 0) and then (u^.station.low = 0) then begin
    u^.station.high := 16#08001E;
    u^.station.low := node_$me;
  end;
  pcb.cmd := eth_cmd_configure_memory;
  pcb.len := 12;
  pcb.words[1] := 16#0400;
  pcb.words[2] := 16#0200;
  pcb.words[3] := 16#1100;
  pcb.words[4] := 16#2000;
  pcb.words[5] := 16#2000;
  pcb.words[6] := 16#0500;
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_configure_memory + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_set_station_address;
  pcb.len := 6;
  pcb.addrs[1].high := u^.station.high;
  pcb.addrs[1].low := u^.station.low;
  if (pcb.addrs[1].high = 0) or else (pcb.addrs[1].low = 0) then
    crash_system(status_$eth_illegal_dest_address);
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_set_station_address + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_load_multicast;
  pcb.len := 12;
  pcb.addrs[1].high := 16#09001E;
  pcb.addrs[1].low := 0;
  pcb.addrs[2].high := 16#09001E;
  pcb.addrs[2].low := 1;
  if not ethernet_do_cmd_polled(u, addr(pcb),
                                eth_cmd_load_multicast + eth_cmd_reply,
                                status) then
    return;
  pcb.cmd := eth_cmd_configure_82586;
  pcb.len := 2;
  pcb.words[1] := 16#0200;
  u^.flags := u^.flags - [eth_unit_cfg_3];
  discard(ethernet_do_cmd_polled(u, addr(pcb),
                                 eth_cmd_configure_82586 + eth_cmd_reply,
                                 status));
end;
