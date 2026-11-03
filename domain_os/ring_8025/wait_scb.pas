{ ring_8025_wait_scb - wait for the controller to finish a command.

  Image addresses:
    sau8  0x03C89706  ring_8025_wait_scb
    sau9  0x3C4852EA  ring_8025_wait_scb

  - Waits for the unit's command eventcount to reach the value
    ring_8025_scb_cmd kept, or for ticks clock ticks.

  Status stored:
    status_$ok: the command completed
    status_$r8025_adapter_hardware_error: the time ran out
}

procedure ring_8025_wait_scb(u: ring_8025_$unit_ptr_t; ticks: integer;
                             out status: status_$t); internal;
var
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  vals: array[1..2] of integer32;
begin
  ecs[1] := addr(u^.scb_ec);
  vals[1] := u^.scb_wait_val;
  ecs[2] := addr(time_$clockh_ec);
  vals[2] := ec_$read(time_$clockh_ec) + ticks * 4;
  case ec_$waitn(ecs, vals, 2) of
    1: status.all := status_$ok;
    2: status.all := status_$r8025_adapter_hardware_error;
  end;
end;
