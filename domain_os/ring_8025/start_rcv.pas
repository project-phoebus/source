{ ring_8025_start_rcv - start the adapter's receiver.

  Image addresses:
    sau8  0x03C8992C  ring_8025_start_rcv
    sau9  0x3C485510  ring_8025_start_rcv

  - Points the unit at its first receive list, marks the two lists
    valid with the interframe wait, passes the receive command and
    waits 5 ticks for it (the outcome not returned), then tells the
    adapter to continue receiving.

  Status stored: none.
}

procedure ring_8025_start_rcv(u: ring_8025_$unit_ptr_t); internal;
var
  status: status_$t;
  i: integer;
begin
  u^.rcv_list := addr(ring8025_$aux_da.ctl[u^.cnum].rcv[1]);
  for i := 1 to r8025_rcv_lists do
    ring8025_$aux_da.ctl[u^.cnum].rcv[i].cstat := [r8025_cstat_valid, r8025_cstat_rcv_ifw];
  u^.scb^.parm := ring_8025_vtop(integer32(u^.rcv_list));
  u^.scb^.cmd := r8025_cmd_receive;
  u^.flags := u^.flags + [r8025_unit_scb_busy];
  u^.scb_wait_val := ec_$read(u^.scb_ec) + 1;
  u^.regs^.sifcmd := r8025_sifcmd_execute;
  ring_8025_wait_scb(u, 5, status);
  u^.regs^.sifcmd := r8025_sifcmd_rcv_continue;
end;
