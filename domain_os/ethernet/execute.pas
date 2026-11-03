{ ethernet_execute - start the program loaded into the adapter.

  Image addresses:
    sau8  0x03C8540E  ethernet_execute
    sau9  0x3C48100E  ethernet_execute

  - With the device's interrupts disabled and under the unit's command
    lock: the execute command, at the given start; the adapter resets
    (both status flags up, then down, eth_reset_polls polls each), is
    set up again and given the program's command 16#17; then its command
    interrupt and the device are enabled and the unit marked as running
    the program.  A step that fails leaves the device disabled.

  Status stored:
    io_$disable_device's status: the execute command was not taken
      (overwritten by the later steps' otherwise)
    ethernet_send_pcb's, ethernet_setup's or io_$enable_device's status:
      that step
    status_$eth_adapter_hardware_error: the adapter did not reset
}

procedure ethernet_execute(u: ethernet_$unit_ptr_t; start: integer;
                           out status: status_$t);
  internal;
label
  done;
var
  pcb: ethernet_$pcb_t;
  cnt: integer32;
  s: ethernet_$asr_t;
begin
  pcb.cmd := eth_cmd_execute_program;
  pcb.len := 2;
  pcb.words[1] := start;
  io_$disable_device(u^.io_unit, status);
  ml_$exclusion_start(u^.cmd_lock);
  if ethernet_send_pcb(u, addr(pcb), status) then begin
    cnt := eth_reset_polls;
    repeat
      if cnt = 0 then begin
        status.all := status_$eth_adapter_hardware_error;
        goto done;
      end;
      cnt := cnt - 1;
      s := u^.regs^.status;
    until (eth_asr_asf1 in s) and then (eth_asr_asf2 in s);
    cnt := eth_reset_polls;
    repeat
      if cnt = 0 then begin
        status.all := status_$eth_adapter_hardware_error;
        goto done;
      end;
      cnt := cnt - 1;
      s := u^.regs^.status;
    until not (eth_asr_asf1 in s) and then not (eth_asr_asf2 in s);
    ethernet_setup(u, status);
    if status.all = status_$ok then begin
      pcb.cmd := eth_cmd_x17;
      pcb.len := 2;
      pcb.words[1] := 16#0200;
      if ethernet_send_pcb(u, addr(pcb), status) then begin
        u^.regs^.control := u^.regs^.control ! eth_hcr_cmde;
        io_$enable_device(u^.io_unit, status);
        u^.flags := u^.flags + [eth_unit_program];
      end;
    end;
  end;
done:
  ml_$exclusion_stop(u^.cmd_lock);
end;
