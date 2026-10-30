{ ethernet_start_cmd - send a command block and arm the wait for its
  reply.

  Image addresses:
    sau9  0x3C480802  ethernet_start_cmd

  - The reply's command code and the block it is to be copied into (the
    same block) are kept in the unit, the reply eventcount's next value
    is taken and the command marked pending before the block goes out:
    the interrupt routine matches the reply against them.

  Status stored:
    ethernet_send_pcb's status: the block went out, or not
}

procedure ethernet_start_cmd(u: ethernet_$unit_ptr_t; pcb: ethernet_$pcb_ptr_t;
                             reply_cmd: integer; out status: status_$t);
  internal;
begin
  u^.reply_cmd := reply_cmd;
  u^.reply_pcb := pcb;
  u^.reply_val := ec_$read(u^.reply_ec) + 1;
  u^.flags := u^.flags + [eth_unit_cmd_pending];
  discard(ethernet_send_pcb(u, pcb, status));
end;
