{ ethernet_start_rcv_cond - ask the adapter for the next received packet,
  at interrupt level.

  Image addresses:
    sau6  0x7808A822  ethernet_start_rcv_cond
    sau7  0x3C494DF0  ethernet_start_rcv_cond
    sau8  0x03C885EC  ethernet_start_rcv_cond
    sau9  0x3C4841EC  ethernet_start_rcv_cond

  - ethernet_start_rcv without waiting: only if the unit's command lock
    is free.  The result is true when the receive command went out.
  - The block's two longwords are the adapter's buffer offset and
    segment (0) and the buffer's length and the time-out, low byte
    first, as the image has them (a length of 1514 here, where
    ethernet_start_rcv has 1258).
  - With `ethernet_vme': ethernet_start_rcv's form without waiting, the
    result true when the request went out.

  Status stored:
    status_$ok: the command lock was held, nothing was sent
    ethernet_send_pcb's status: the command went out, or not
    with `ethernet_vme':
      ethernet_start_cmd's status: the request went out, or not
      status_$eth_adapter_hardware_error: the buffer is still busy
}

function ethernet_start_rcv_cond(u: ethernet_$unit_ptr_t;
                                 out status: status_$t): boolean;
  internal;
%if ethernet_vme %then
var
  started: boolean;
begin
  started := false;
  if ml_$cond_exclusion_start(u^.cmd_lock) then
    status.all := status_$ok
  else begin
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
        started := true;
        u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
        u^.rcv_idx := (u^.rcv_idx mod 2) + 1;
      end
      else
        u^.rcv_busy[u^.rcv_idx] := false;
    end;
    ml_$cond_exclusion_stop(u^.cmd_lock);
  end;
  ethernet_start_rcv_cond := started;
end;
%else
var
  pcb: ethernet_$pcb_t;
  started: boolean;
begin
  started := false;
  pcb.cmd := eth_cmd_receive_packet;
  pcb.len := 8;
  pcb.longs[1] := 0;
  pcb.longs[2] := 16#EA050000;
  if ml_$cond_exclusion_start(u^.cmd_lock) then
    status.all := status_$ok
  else begin
    u^.flags := u^.flags + [eth_unit_rcv_pending];
    if not ethernet_send_pcb(u, addr(pcb), status) then
      u^.flags := u^.flags - [eth_unit_rcv_pending]
    else
      started := true;
    ml_$cond_exclusion_stop(u^.cmd_lock);
  end;
  ethernet_start_rcv_cond := started;
end;
%endif
