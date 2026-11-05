{ ethernet_start_cmd - send a command block and arm the wait for its
  reply.

  Image addresses:
    sau6  0x78086A88  ethernet_start_cmd
    sau7  0x3C491406  ethernet_start_cmd
    sau8  0x03C84C02  ethernet_start_cmd
    sau9  0x3C480802  ethernet_start_cmd

  - The reply's command code and the block it is to be copied into (the
    same block) are kept in the unit, the reply eventcount's next value
    is taken and the command marked pending before the block goes out:
    the interrupt routine matches the reply against them.
  - With `ethernet_vme': the request is the one in the command ring's
    next slot; its length comes from the request, the slot is given the
    reply eventcount's next value as its identifier and handed to the
    controller, and a zero byte written to the command register tells
    the controller.

  Status stored:
    ethernet_send_pcb's status: the block went out, or not
    with `ethernet_vme':
      ethernet_kick's status: the controller was told, or not
      status_$eth_internal_driver_error: the slot's request is not one
        the driver gives
}

%if ethernet_vme %then
procedure ethernet_start_cmd(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
begin
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    u^.reply_cmd := request;
    case request of
      eth_vme_cmd_x08: begin
        len := 11;
      end;
      eth_vme_cmd_x0a: begin
        len := 10;
      end;
      eth_vme_cmd_read_stats: begin
        len := 18;
      end;
      eth_vme_cmd_set_address, eth_vme_cmd_receive: begin
        len := 16;
      end;
      eth_vme_cmd_transmit, eth_vme_cmd_x0e: begin
        len := value * 6 + 10;
      end;
      otherwise begin
        status.all := status_$eth_internal_driver_error;
        return;
      end;
    end;
    byte_02 := 0;
    word_06 := 0;
    u^.reply_val := ec_$read(u^.reply_ec) + 1;
    id := u^.reply_val;
    u^.reply_id := u^.reply_val;
    u^.flags := u^.flags + [eth_unit_cmd_pending];
    owner := owner + [eth_vme_slot_ctlr];
  end;
  discard(ethernet_kick(u^.regs, 0, status));
end;
%else

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
%endif
