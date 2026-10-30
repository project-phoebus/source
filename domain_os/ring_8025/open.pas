{ ring_8025_open - open a unit's adapter onto the ring.

  Image addresses:
    sau9  0x3C485368  ring_8025_open

  - Fills the open parameters in the unit's control area (the station
    address 50-00-78 and the node's ID's low 24 bits, 26 transmit and
    receive lists, 1280-byte buffers) and passes the open command; the
    open is waited for 30 ticks.
  - The interrupt routine marks the unit open when the adapter reports
    the open's success; a completed command without it is a failure.

  Status stored:
    status_$ok: the adapter is on the ring
    ring_8025_wait_scb's status: the command did not complete
    status_$r8025_adapter_hardware_error: the open did not succeed
}

procedure ring_8025_open(u: ring_8025_$unit_ptr_t; out status: status_$t);
  internal;
begin
  with ring8025_$aux_da.ctl[u^.cnum] do begin
    open_parms.options := 0;
    open_parms.node.high := r8025_addr_high;
    open_parms.node.low := node_$me;
    open_parms.group := 0;
    open_parms.funct := 0;
    open_parms.rcv_list_size := 26;
    open_parms.xmit_list_size := 26;
    open_parms.buf_size := 1280;
    open_parms.ram_end := 16#7FFE;
    open_parms.ram_start := 16#4006;
    open_parms.xmit_buf_min := 4;
    open_parms.xmit_buf_max := 4;
    open_parms.product_id_pa := ring_8025_vtop(integer32(addr(product_id)));
  end;
  ring_8025_scb_cmd(u, r8025_cmd_open,
                    addr(ring8025_$aux_da.ctl[u^.cnum].open_parms),
                    sizeof(ring_8025_$open_parms_t));
  ring_8025_wait_scb(u, 30, status);
  if (status.all = status_$ok) and then not u^.cmd_ssb.opened then
    status.all := status_$r8025_adapter_hardware_error;
end;
