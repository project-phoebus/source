{ ring_8025_close - take a unit's adapter off the ring.

  Image addresses:
    sau9  0x3C485442  ring_8025_close

  - Passes the close command with a word of the frame as its block and
    waits 5 ticks for it; the outcome is not returned.

  Status stored: none.
}

procedure ring_8025_close(u: ring_8025_$unit_ptr_t); internal;
var
  status: status_$t;
  parm: integer;
begin
  ring_8025_scb_cmd(u, r8025_cmd_close, addr(parm), 2);
  ring_8025_wait_scb(u, 5, status);
end;
