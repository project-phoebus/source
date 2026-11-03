{ ethernet_transmit - give the adapter a packet from a list of pieces.

  Image addresses:
    sau8  0x03C8551E  ethernet_transmit
    sau9  0x3C48111E  ethernet_transmit

  - The memory control register's bit 8 is changed first.
  - Under the unit's command lock; the pieces go through the data
    register one after another until one fails.
  - With the downloaded program running: its transmit command (16#18)
    with the packet's length; when the adapter shows ASF3 the command is
    given once more after the adapter's transmit eventcount advances (4
    clock ticks at most).  No reply is awaited.
  - Else the 3C505's transmit command, and its completion is awaited;
    a completion with a nonzero result word is a failed transmit.

  Status stored:
    ethernet_send_pcb's status: the command was not taken
    ethernet_start_cmd's status: the command did not go out
    ethernet_$$pio_write's status: a piece did not go out
    ethernet_wait_cmd's status: the completion did not come
    status_$eth_adapter_hardware_error: the adapter's eventcount did
      not advance
    status_$eth_transmit_failed: the completion's result was not 0
}

procedure ethernet_transmit(u: ethernet_$unit_ptr_t;
                            pieces: ethernet_$xmit_list_ptr_t;
                            count: integer; total: integer;
                            out status: status_$t);
  internal;
var
  pcb: ethernet_$pcb_t;
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  i: integer;
begin
  mmu_$mcr_change(8);
  if eth_unit_program in u^.flags then begin
    pcb.cmd := eth_cmd_x18;
    pcb.len := 2;
    pcb.words[1] := lshft(total, 8) ! rshft(total, 8);
    ml_$exclusion_start(u^.cmd_lock);
    vals[1] := ec_$read(u^.ec_1280) + 1;
    if ethernet_send_pcb(u, addr(pcb), status) then
      if eth_asr_asf3 in u^.regs^.status then begin
        ecs[1] := addr(u^.ec_1280);
        ecs[2] := addr(time_$clockh_ec);
        vals[2] := ec_$read(time_$clockh_ec) + 4;
        case ec_$waitn(ecs, vals, 2) of
          1: discard(ethernet_send_pcb(u, addr(pcb), status));
          2: status.all := status_$eth_adapter_hardware_error;
        end;
      end;
    i := 1;
    while (i <= count) and then (status.all = status_$ok) do begin
      discard(ethernet_$$pio_write(u^.regs, pieces^[i].va, pieces^[i].len,
                                   status));
      i := i + 1;
    end;
    ml_$exclusion_stop(u^.cmd_lock);
  end
  else begin
    pcb.cmd := eth_cmd_transmit_packet;
    pcb.len := 6;
    pcb.words[1] := 0;
    pcb.words[2] := 0;
    pcb.words[3] := lshft(total, 8) ! rshft(total, 8);
    ml_$exclusion_start(u^.cmd_lock);
    ethernet_start_cmd(u, addr(pcb),
                       eth_cmd_transmit_packet + eth_cmd_reply, status);
    i := 1;
    while (i <= count) and then (status.all = status_$ok) do begin
      discard(ethernet_$$pio_write(u^.regs, pieces^[i].va, pieces^[i].len,
                                   status));
      i := i + 1;
    end;
    if status.all = status_$ok then
      ethernet_wait_cmd(u, status)
    else
      u^.flags := u^.flags - [eth_unit_cmd_pending];
    ml_$exclusion_stop(u^.cmd_lock);
    if status.all = status_$ok then
      if pcb.words[3] <> 0 then
        status.all := status_$eth_transmit_failed;
  end;
end;
