{ ethernet_wait_cmd - wait for a command's reply.

  Image addresses:
    sau8  0x03C84C48  ethernet_wait_cmd
    sau9  0x3C480848  ethernet_wait_cmd

  - The reply eventcount is waited for, eight clock ticks at most.

  Status stored:
    status_$ok: the reply came
    status_$eth_adapter_hardware_error: it timed out
}

procedure ethernet_wait_cmd(u: ethernet_$unit_ptr_t; out status: status_$t);
  internal;
var
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
begin
  ecs[1] := addr(u^.reply_ec);
  vals[1] := u^.reply_val;
  ecs[2] := addr(time_$clockh_ec);
  vals[2] := ec_$read(time_$clockh_ec) + 8;
  case ec_$waitn(ecs, vals, 2) of
    1: status.all := status_$ok;
    2: status.all := status_$eth_adapter_hardware_error;
  end;
end;
