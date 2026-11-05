{ ethernet_get_pcb - take a command block from the adapter.

  Image addresses:
    sau7  0x3C491274  ethernet_get_pcb
    sau8  0x03C84A74  ethernet_get_pcb
    sau9  0x3C480674  ethernet_get_pcb

  - The bytes from `first' on are read from the command register as the
    adapter offers them (ACRF), until it marks the end (both status
    flags) or the block is full; the caller has read those before
    `first'.  Each byte is waited for eth_reply_byte_polls polls at
    most.
  - The adapter sends the block's length as its last byte.  When that
    agrees with the block's own length byte and with the bytes read,
    the block is acknowledged (HSF1), else refused (HSF2).

  Status stored:
    status_$ok: the block was taken and acknowledged
    status_$eth_adapter_hardware_error: a byte did not come, or the
      block was refused
}

function ethernet_get_pcb(u: ethernet_$unit_ptr_t; pcb: ethernet_$pcb_ptr_t;
                          first: integer; out status: status_$t): boolean;
  internal;
var
  i: pinteger;
%if ethernet_long_polls %then
  t: integer32;
%else
  t: pinteger;
%endif
  s: ethernet_$asr_t;
  last: pinteger;
begin
  u^.regs^.control := u^.regs^.control & ~(eth_hcr_hsf1 ! eth_hcr_hsf2);
  for i := first to eth_pcb_max do begin
    t := eth_reply_byte_polls;
    repeat
      if t = 0 then begin
        status.all := status_$eth_adapter_hardware_error;
        ethernet_get_pcb := false;
        return;
      end;
      t := t - 1;
      s := u^.regs^.status;
    until eth_asr_acrf in s;
    if (eth_asr_asf1 in s) and then (eth_asr_asf2 in s) then
      exit;
    pcb^.bytes[i] := u^.regs^.command;
  end;
  last := u^.regs^.command;
  if (last = pcb^.len + 2) and then (last = i - 1) then begin
    u^.regs^.control := u^.regs^.control ! eth_hcr_hsf1;
    status.all := status_$ok;
  end
  else begin
    u^.regs^.control := u^.regs^.control ! eth_hcr_hsf2;
    status.all := status_$eth_adapter_hardware_error;
  end;
  ethernet_get_pcb := status.all = status_$ok;
end;
