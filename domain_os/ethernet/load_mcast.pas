{ ethernet_load_mcast - load the unit's multicast list into the adapter.

  Image addresses:
    sau8  0x03C86116  ethernet_load_mcast
    sau9  0x3C481D16  ethernet_load_mcast

  - The 82586 is configured with receive mode 1 (cfg_3 set) or 0 while
    the list is loaded: first an empty list, then Apollo's two multicast
    addresses, then the unit's addresses in use, ten at most a command.
    Receive mode 3 or 2 is set again at the end.
  - A reply with a nonzero result word is an error.  The empty list's
    reply word is checked only when its command failed.
  - The first step that fails ends it.

  Status stored:
    ethernet_do_cmd's status: a command or its reply failed
    status_$eth_adapter_hardware_error: a reply's result was not 0
}

procedure ethernet_load_mcast(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
  i: integer;
  j: integer;
  n: pinteger;
begin
  pcb.cmd := eth_cmd_configure_82586;
  pcb.len := 2;
  if eth_unit_cfg_3 in u^.flags then
    pcb.words[1] := 16#0100
  else
    pcb.words[1] := 16#0000;
  if ethernet_do_cmd(u, addr(pcb), eth_cmd_configure_82586 + eth_cmd_reply,
                     status) then
    if pcb.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
  if status.all <> status_$ok then
    return;
  pcb.cmd := eth_cmd_load_multicast;
  pcb.len := 0;
  if not ethernet_do_cmd(u, addr(pcb), eth_cmd_load_multicast + eth_cmd_reply,
                         status) then
    if pcb.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
  if status.all <> status_$ok then
    return;
  pcb.cmd := eth_cmd_load_multicast;
  pcb.len := 12;
  pcb.addrs[1].high := eth_apollo_mcast_high;
  pcb.addrs[1].low := 0;
  pcb.addrs[2].high := eth_apollo_mcast_high;
  pcb.addrs[2].low := 1;
  if ethernet_do_cmd(u, addr(pcb), eth_cmd_load_multicast + eth_cmd_reply,
                     status) then
    if pcb.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
  if status.all <> status_$ok then
    return;
  n := 0;
  j := 1;
  i := 1;
  while n < u^.mcast_count do begin
    if u^.mcast[i].count > 0 then begin
      n := n + 1;
      pcb.addrs[j] := u^.mcast[i].addr;
      if (j >= 10) or else (n >= u^.mcast_count) then begin
        pcb.cmd := eth_cmd_load_multicast;
        pcb.len := j * 6;
        if ethernet_do_cmd(u, addr(pcb),
                           eth_cmd_load_multicast + eth_cmd_reply,
                           status) then
          if pcb.words[1] <> 0 then
            status.all := status_$eth_adapter_hardware_error;
        if status.all <> status_$ok then
          return;
        j := 1;
      end
      else
        j := j + 1;
    end;
    i := i + 1;
  end;
  pcb.cmd := eth_cmd_configure_82586;
  pcb.len := 2;
  if eth_unit_cfg_3 in u^.flags then
    pcb.words[1] := 16#0300
  else
    pcb.words[1] := 16#0200;
  if ethernet_do_cmd(u, addr(pcb), eth_cmd_configure_82586 + eth_cmd_reply,
                     status) then
    if pcb.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
end;
