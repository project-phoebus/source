{ ring_8025_start_xmit - start the adapter's transmitter.

  Image addresses:
    sau7  0x3C4961A6  ring_8025_start_xmit
    sau8  0x03C89896  ring_8025_start_xmit
    sau9  0x3C48547A  ring_8025_start_xmit

  - Points the unit at its first transmit list, clears the three lists'
    CSTAT flags, and passes the transmit command with the command
    block request (the adapter interrupts when the block is free); waits
    5 ticks for it, the outcome not returned.

  Status stored: none.
}

procedure ring_8025_start_xmit(u: ring_8025_$unit_ptr_t); internal;
var
  status: status_$t;
  i: integer;
begin
  u^.xmit_list := addr(ring8025_$aux_da.ctl[u^.cnum].xmit[1]);
  for i := 1 to r8025_xmit_lists do
    ring8025_$aux_da.ctl[u^.cnum].xmit[i].cstat := [];
%if ring_8025_iomap %then
  u^.scb^.parm := ring_8025_vtop(integer32(u^.xmit_list),
                                 sizeof(ring_8025_$list_t),
                                 u^.iomap_page + r8025_map_ctl);
%else
  u^.scb^.parm := ring_8025_vtop(integer32(u^.xmit_list));
%endif
  u^.scb^.cmd := r8025_cmd_transmit;
  u^.flags := u^.flags + [r8025_unit_scb_busy];
  u^.scb_wait_val := ec_$read(u^.scb_ec) + 1;
  u^.regs^.sifcmd := r8025_sifcmd_execute_scb_req;
  ring_8025_wait_scb(u, 5, status);
end;
