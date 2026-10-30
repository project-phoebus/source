{ ring_8025_xmit_halt - stop the adapter's transmitter.

  Image addresses:
    sau9  0x3C4855B2  ring_8025_xmit_halt

  - Passes the transmit halt command with a word of the frame as its
    block and waits 3 ticks for it; the outcome is not returned.

  Status stored: none.
}

procedure ring_8025_xmit_halt(u: ring_8025_$unit_ptr_t); internal;
var
  status: status_$t;
  parm: integer;
begin
  ring_8025_scb_cmd(u, r8025_cmd_transmit_halt, addr(parm), 2);
  ring_8025_wait_scb(u, 3, status);
end;
