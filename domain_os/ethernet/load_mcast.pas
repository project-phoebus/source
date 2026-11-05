{ ethernet_load_mcast - load the unit's multicast list into the adapter.

  Image addresses:
    sau6  0x78088482  ethernet_load_mcast
    sau7  0x3C49291A  ethernet_load_mcast
    sau8  0x03C86116  ethernet_load_mcast
    sau9  0x3C481D16  ethernet_load_mcast

  - The 82586 is configured with receive mode 1 (cfg_3 set) or 0 while
    the list is loaded: first an empty list, then Apollo's two multicast
    addresses, then the unit's addresses in use, ten at most a command.
    Receive mode 3 or 2 is set again at the end.
  - A reply with a nonzero result word is an error.  The empty list's
    reply word is checked only when its command failed.
  - The first step that fails ends it.
  - With `ethernet_vme': the controller holds the addresses in entries
    of its own, the list's entry i in the controller's i + 2.  A free
    entry still loaded is taken out; an entry in use not yet loaded is
    given its address (crashing the system when it is zero) and turned
    on.  Every entry is tried; the first failure's status is kept.

  Status stored:
    ethernet_do_cmd's status: a command or its reply failed
    status_$eth_adapter_hardware_error: a reply's result was not 0
    with `ethernet_vme': the first failing request's status, else the
      last request's
}

%if ethernet_vme %then
procedure ethernet_load_mcast(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  first: status_$t;
  i: integer;
begin
  first.all := status_$ok;
  for i := 1 to 15 do
    if u^.mcast[i].count = 0 then begin
      if u^.mcast[i].loaded <> 0 then begin
        { a free entry still loaded: take it out }
        ml_$exclusion_start(u^.cmd_lock);
        with u^.cmd_ring^.slots[u^.cmd_idx] do begin
          request := eth_vme_cmd_x0a;
          param := 1;
          value := i + 2;
        end;
        ethernet_start_cmd(u, status);
        if status.all = status_$ok then begin
          u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
          ethernet_wait_cmd(u, status);
        end
        else
          u^.flags := u^.flags - [eth_unit_cmd_pending];
        ml_$exclusion_stop(u^.cmd_lock);
        if (status.all <> status_$ok) and then (first.all = status_$ok) then
          first := status;
        u^.mcast[i].loaded := 0;
      end;
    end
    else if u^.mcast[i].loaded = 0 then begin
      { an entry in use not loaded yet: its address, then turned on }
      ml_$exclusion_start(u^.cmd_lock);
      with u^.cmd_ring^.slots[u^.cmd_idx] do begin
        request := eth_vme_cmd_set_address;
        param_2 := 1;
        value_2 := i + 2;
        hw_addr := u^.mcast[i].addr;
        if (hw_addr.high = 0) and then (hw_addr.low = 0) then
          crash_system(status_$eth_illegal_dest_address);
      end;
      ethernet_start_cmd(u, status);
      if status.all = status_$ok then begin
        u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
        ethernet_wait_cmd(u, status);
      end
      else
        u^.flags := u^.flags - [eth_unit_cmd_pending];
      ml_$exclusion_stop(u^.cmd_lock);
      if status.all <> status_$ok then
        if first.all = status_$ok then
          first := status;
      if status.all = status_$ok then begin
        ml_$exclusion_start(u^.cmd_lock);
        with u^.cmd_ring^.slots[u^.cmd_idx] do begin
          request := eth_vme_cmd_x0a;
          param := 5;
          value := i + 2;
        end;
        ethernet_start_cmd(u, status);
        if status.all = status_$ok then begin
          u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
          ethernet_wait_cmd(u, status);
        end
        else
          u^.flags := u^.flags - [eth_unit_cmd_pending];
        ml_$exclusion_stop(u^.cmd_lock);
        if status.all = status_$ok then
          u^.mcast[i].loaded := i + 2
        else if first.all = status_$ok then
          first := status;
      end;
    end;
  if first.all <> status_$ok then
    status := first;
end;
%else
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
%endif
