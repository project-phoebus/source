{ ethernet_transmit - give the adapter a packet from a list of pieces.

  Image addresses:
    sau6  0x7808788E  ethernet_transmit
    sau7  0x3C491D22  ethernet_transmit
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
  - With `ethernet_vme': under the transmit lock; a busy transmit
    buffer is waited for (eight clock ticks at most).  Then under the
    command lock the packet goes into a command slot as fragments: a
    piece whose physical address the controller reaches is given where
    it is, the others are copied into the buffer, a copied piece after
    another merged with it.  The data page is kept to be given back when
    the transmit completes.  The slot and the buffer move on once the
    request is out; else the buffer is free again.

  Status stored:
    ethernet_send_pcb's status: the command was not taken
    ethernet_start_cmd's status: the command did not go out
    ethernet_$$pio_write's status: a piece did not go out
    ethernet_wait_cmd's status: the completion did not come
    status_$eth_adapter_hardware_error: the adapter's eventcount did
      not advance
    status_$eth_transmit_failed: the completion's result was not 0
    with `ethernet_vme':
      status_$eth_adapter_hardware_error: the buffer stayed busy
      ethernet_start_cmd's status: otherwise
}

%if ethernet_vme %then
procedure ethernet_transmit(u: ethernet_$unit_ptr_t;
                            pieces: ethernet_$xmit_list_ptr_t;
                            count: integer;
                            pas: ethernet_$xmit_pa_list_ptr_t;
                            total: integer; dat: integer32;
                            out status: status_$t);
  internal;
var
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  bus: ethernet_$vme_bus_t;
  va: pkt_$bytes_ptr_t;
  last: integer;
  i: integer;
  n: integer;
  off: integer;
  plen: integer;
  dst: integer32;
begin
  mmu_$mcr_change(8);
  ml_$exclusion_start(u^.xmit_lock);
  if u^.xmit_busy[u^.xmit_idx] then begin
    u^.flags := u^.flags + [eth_unit_xmit_wait];
    if u^.xmit_busy[u^.xmit_idx] then begin
      ecs[1] := addr(u^.xmit_wait_ec);
      vals[1] := ec_$read(u^.xmit_wait_ec) + 1;
      ecs[2] := addr(time_$clockh_ec);
      vals[2] := ec_$read(time_$clockh_ec) + 8;
      case ec_$waitn(ecs, vals, 2) of
        1: status.all := status_$ok;
        2: status.all := status_$eth_adapter_hardware_error;
      end;
      u^.flags := u^.flags - [eth_unit_xmit_wait];
      if u^.xmit_busy[u^.xmit_idx] or else (status.all <> status_$ok) then begin
        ml_$exclusion_stop(u^.xmit_lock);
        status.all := status_$eth_adapter_hardware_error;
        return;
      end;
    end
    else
      u^.flags := u^.flags - [eth_unit_xmit_wait];
  end;
  ml_$exclusion_start(u^.cmd_lock);
  u^.xmit_dat[u^.xmit_idx] := dat;
  with u^.cmd_ring^.slots[u^.cmd_idx] do begin
    request := eth_vme_cmd_transmit;
    off := 0;
    n := 0;
    last := 8;
    dst := integer32(addr(ethernet_vme_$sh[u^.cnum].xmit_buf[u^.xmit_idx]));
    for i := 1 to count do
      if pas^[i] < eth_vme_dma_limit then begin
        n := n + 1;
        frags[n].len := pieces^[i].len;
        bus.all := pas^[i] - eth_vme_dma_base;
        bus.space := eth_vme_bus_space;
        frags[n].bus := bus.all;
      end
      else begin
        va := pieces^[i].va;
        plen := pieces^[i].len;
        os_$data_copy(va^, pkt_$bytes_ptr_t(dst)^, plen);
        if last + 1 = i then
          frags[n].len := frags[n].len + plen
        else begin
          n := n + 1;
          frags[n].len := plen;
          frags[n].bus := off + u^.xmit_bus[u^.xmit_idx];
        end;
        dst := dst + plen;
        off := off + plen;
        last := i;
      end;
    frag_count := n;
  end;
  u^.xmit_busy[u^.xmit_idx] := true;
  u^.flags := u^.flags + [eth_unit_xmit_busy];
  ethernet_start_cmd(u, status);
  u^.flags := u^.flags - [eth_unit_cmd_pending];
  if status.all = status_$ok then begin
    u^.cmd_idx := (u^.cmd_idx mod eth_vme_ring_slots) + 1;
    u^.xmit_idx := (u^.xmit_idx mod 2) + 1;
  end
  else begin
    u^.xmit_busy[u^.xmit_idx] := false;
    if not u^.xmit_busy[(u^.xmit_idx mod 2) + 1] then
      u^.flags := u^.flags - [eth_unit_xmit_busy];
  end;
  ml_$exclusion_stop(u^.cmd_lock);
  ml_$exclusion_stop(u^.xmit_lock);
end;
%else
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
%endif
