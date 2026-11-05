{ ethernet_do_cmd_polled - give the adapter a command and poll for its
  reply.

  Image addresses:
    sau7  0x3C491642  ethernet_do_cmd_polled
    sau8  0x03C84E3E  ethernet_do_cmd_polled
    sau9  0x3C480A3E  ethernet_do_cmd_polled

  - For the setup, before the adapter's interrupts are used: the
    adapter's blocks are read into the command's block until the reply
    of the given code comes; a reply with a nonzero result word is an
    error.

  Status stored:
    ethernet_send_pcb's status: the block did not go out
    ethernet_get_pcb's status: a block could not be read
    status_$ok: the reply came and its result was 0
    status_$eth_adapter_hardware_error: its result was not 0
}

function ethernet_do_cmd_polled(u: ethernet_$unit_ptr_t;
                                pcb: ethernet_$pcb_ptr_t;
                                reply_cmd: integer;
                                out status: status_$t): boolean;
  internal;
begin
  if ethernet_send_pcb(u, pcb, status) then
    repeat
      discard(ethernet_get_pcb(u, pcb, 1, status));
    until (status.all <> status_$ok) or else (pcb^.cmd = reply_cmd);
  if status.all = status_$ok then
    if pcb^.words[1] <> 0 then
      status.all := status_$eth_adapter_hardware_error;
  ethernet_do_cmd_polled := status.all = status_$ok;
end;
