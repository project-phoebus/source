{ ethernet_start_rcv - ask the adapter for the next received packet.

  Image addresses:
    sau6  0x78086C2E  ethernet_start_rcv
    sau7  0x3C491568  ethernet_start_rcv
    sau8  0x03C84D64  ethernet_start_rcv
    sau9  0x3C480964  ethernet_start_rcv

  - Under the unit's command lock.  The receive command is marked
    pending before it goes out, and unmarked if the adapter does not
    take it; the packet comes later, with the command's completion.
  - The block's two longwords are the adapter's buffer offset and
    segment (0) and the buffer's length and the time-out, low byte
    first, as the image has them.
  - With `ethernet_vme': the next receive buffer is given to the
    controller in the command ring's next slot, unless it is still
    busy; the ring's and the buffers' indices move on once the request
    is out, and the buffer is free again if it is not.

  Status stored:
    ethernet_send_pcb's status: the command went out, or not
    with `ethernet_vme':
      ethernet_start_cmd's status: the request went out, or not
      status_$eth_adapter_hardware_error: the buffer is still busy
}

%if ethernet_vme %then
procedure ethernet_start_rcv(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
begin
  ml_$exclusion_start(u^.cmd_lock);
  if u^.rcv_busy[u^.rcv_idx] then
    status.all := status_$eth_adapter_hardware_error
  else begin
    with u^.cmd_ring^.slots[u^.cmd_idx] do begin
      request := eth_vme_cmd_receive;
      value := 1;
      data_len := eth_vme_rcv_buf_len;
      buf := u^.rcv_bus[u^.rcv_idx];
    end;
    u^.rcv_busy[u^.rcv_idx] := true;
    ethernet_start_cmd(u, status);
    u^.flags := u^.flags - [eth_unit_cmd_pending];
    if status.all = status_$ok then begin
      u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
      u^.rcv_idx := (u^.rcv_idx mod 2) + 1;
    end
    else
      u^.rcv_busy[u^.rcv_idx] := false;
  end;
  ml_$exclusion_stop(u^.cmd_lock);
end;
%else

procedure ethernet_start_rcv(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
begin
  pcb.cmd := eth_cmd_receive_packet;
  pcb.len := 8;
  pcb.longs[1] := 0;
  pcb.longs[2] := 16#EA050000;
  ml_$exclusion_start(u^.cmd_lock);
  u^.flags := u^.flags + [eth_unit_rcv_pending];
  if not ethernet_send_pcb(u, addr(pcb), status) then
    u^.flags := u^.flags - [eth_unit_rcv_pending];
  ml_$exclusion_stop(u^.cmd_lock);
end;
%endif
