{ ethernet_start_rcv - ask the adapter for the next received packet.

  Image addresses:
    sau8  0x03C84D64  ethernet_start_rcv
    sau9  0x3C480964  ethernet_start_rcv

  - Under the unit's command lock.  The receive command is marked
    pending before it goes out, and unmarked if the adapter does not
    take it; the packet comes later, with the command's completion.
  - The block's two longwords are the adapter's buffer offset and
    segment (0) and the buffer's length and the time-out, low byte
    first, as the image has them.

  Status stored:
    ethernet_send_pcb's status: the command went out, or not
}

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
