{ ethernet_configure - set the 82586's receive mode.

  Image addresses:
    sau6  0x78086CD8  ethernet_configure
    sau7  0x3C4915CA  ethernet_configure
    sau8  0x03C84DC6  ethernet_configure
    sau9  0x3C4809C6  ethernet_configure

  - The adapter's Ethernet chip is configured with receive mode 3 when
    cfg_3 is true, else 2 (the configuration word, low byte first); the
    unit's eth_unit_cfg_3 follows a configuration that succeeded.  A
    reply with a nonzero result word is an error.
  - With `ethernet_vme': under the unit's command lock, the controller
    is given eth_vme_cmd_x0a with parameter 5 when cfg_3 is true, else
    1, and the reply is waited for.

  Status stored:
    ethernet_do_cmd's status: the command or its reply failed
    status_$eth_adapter_hardware_error: the reply's result was not 0
    with `ethernet_vme':
      ethernet_start_cmd's or ethernet_wait_cmd's status
}

%if ethernet_vme %then
procedure ethernet_configure(u: ethernet_$unit_ptr_t; cfg_3: boolean;
                             out status: status_$t);
  internal;
begin
  ml_$exclusion_start(u^.cmd_lock);
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_x0a;
    if cfg_3 then
      param := 5
    else
      param := 1;
    value := 16#FF;
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
    if cfg_3 then
      u^.flags := u^.flags + [eth_unit_cfg_3]
    else
      u^.flags := u^.flags - [eth_unit_cfg_3];
end;
%else

procedure ethernet_configure(u: ethernet_$unit_ptr_t; cfg_3: boolean;
                             out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
begin
  pcb.cmd := eth_cmd_configure_82586;
  pcb.len := 2;
  if cfg_3 then
    pcb.words[1] := 16#0300
  else
    pcb.words[1] := 16#0200;
  if ethernet_do_cmd(u, addr(pcb), eth_cmd_configure_82586 + eth_cmd_reply,
                     status) then
    if pcb.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
  if status.all = status_$ok then
    if cfg_3 then
      u^.flags := u^.flags + [eth_unit_cfg_3]
    else
      u^.flags := u^.flags - [eth_unit_cfg_3];
end;
%endif
