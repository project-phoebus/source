{ ring_$set_rx_buffer - give the controller the buffer to receive into.

  Image addresses:
    sau7  0x3C48DDAE  ring_$set_rx_buffer (module-local)
    sau8  0x03C815AE  ring_$set_rx_buffer (module-local)
    sau9  0x3C47D1AE  ring_$set_rx_buffer (module-local)

  - The receive's word limit is loaded with limit, the received
    header's and data's counters are restarted, and the buffer's word
    address in the controller's memory goes into rx_ptr with its bytes
    swapped.  The receive itself is started by its caller.

  Status stored: none.
}

procedure ring_$set_rx_buffer(ctlr_addr: pinteger; var regs: ring8_$csr_t;
                              limit: integer);
  internal;
begin
  ring_$set_timer(limit, ring8_cnt_rx_limit, regs);
  regs.timer_a_ctl := 16#3000;
  regs.timer_a[0] := 16#FF00;
  regs.timer_a[0] := 16#FF00;
  regs.timer_a_ctl := 16#7000;
  regs.timer_a[1] := 16#FF00;
  regs.timer_a[1] := 16#FF00;
  regs.rx_ptr := lshft(ctlr_addr & 16#FF, 8) + rshft(ctlr_addr, 8);
end;
