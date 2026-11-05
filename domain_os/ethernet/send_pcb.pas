{ ethernet_send_pcb - give the adapter a command block.

  Image addresses:
    sau7  0x3C491332  ethernet_send_pcb
    sau8  0x03C84B2E  ethernet_send_pcb
    sau9  0x3C48072E  ethernet_send_pcb

  - The block's bytes go through the command register, each after the
    adapter has emptied it (HCRE, eth_cmd_byte_polls polls at most);
    then both host flags mark the end and the length goes as the last
    byte.  The adapter answers with ASF1 (taken) or ASF2 (refused),
    waited for eth_cmd_answer_polls polls at most.  The host flags are
    cleared again on every way out but a byte's time-out.

  Status stored:
    status_$ok: the adapter took the block
    status_$eth_adapter_hardware_error: a byte or the answer timed out,
      or the adapter refused the block
}

function ethernet_send_pcb(u: ethernet_$unit_ptr_t; pcb: ethernet_$pcb_ptr_t;
                           out status: status_$t): boolean;
  internal;
var
  len: integer;
  i: integer;
%if ethernet_long_polls %then
  t: pinteger;
%else
  t: integer;
%endif
  cnt: integer32;
  s: ethernet_$asr_t;
begin
  len := pcb^.len + 2;
  for i := 1 to len do begin
    u^.regs^.command := pcb^.bytes[i];
    t := eth_cmd_byte_polls;
    repeat
      if t = 0 then begin
        status.all := status_$eth_adapter_hardware_error;
        ethernet_send_pcb := false;
        return;
      end;
      t := t - 1;
      s := u^.regs^.status;
    until eth_asr_hcre in s;
  end;
  with u^.regs^ do begin
    control := control ! (eth_hcr_hsf1 ! eth_hcr_hsf2);
    command := len;
  end;
  cnt := eth_cmd_answer_polls;
  repeat
    if cnt = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_send_pcb := false;
      u^.regs^.control := u^.regs^.control & ~(eth_hcr_hsf1 ! eth_hcr_hsf2);
      return;
    end;
    cnt := cnt - 1;
    s := u^.regs^.status;
    if not (eth_asr_asf1 in s) and then (eth_asr_asf2 in s) then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_send_pcb := false;
      exit;
    end;
    if (eth_asr_asf1 in s) and then not (eth_asr_asf2 in s) then begin
      status.all := status_$ok;
      ethernet_send_pcb := true;
      exit;
    end;
  until false;
  u^.regs^.control := u^.regs^.control & ~(eth_hcr_hsf1 ! eth_hcr_hsf2);
end;
