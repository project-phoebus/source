{ GUARDIAN_PROCESS - a line's guardian process.

  Image addresses:
    sau3  0x00E858AE  GUARDIAN_PROCESS

  - Serves the line iic_guardian_line names when it is created.  It
    waits on five eventcounts: a start or stop request (it starts or
    stops the line and answers on done_ec; after a stop it unbinds
    itself), the other end going down or up (the line's state, under its
    send lock), and a received frame.
  - A received frame whose type falls in a range of an open channel goes
    to MAC_OS_$DEMUX; its buffers are given back when MAC_OS refuses it.
    A frame no channel takes is not given back.
  - The demultiplexing flag is set when the frame's header asks for it
    and is not cleared otherwise.

  Status stored: none.
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure guardian_process;
var
  pkt: mac_os_$rcv_pkt_t;
  ecs: array[1..5] of ec_$eventcount_ptr_t;
  vals: array[1..5] of integer32;
  st: status_$t;
  unbind_st: status_$t;
  bits: pkt_$hdr_bits_t;
  demux_flag: boolean;
  addr_long: iic_$long_ptr_t;
  hdr: iic_$frame_hdr_ptr_t;
  line: pinteger;
  slot: integer;
  i: integer;
  done: boolean;
begin
  line := iic_guardian_line;
  with iic_lines[line] do begin
    ec_$init(start_ec);
    ec_$init(stop_ec);
    ec_$init(down_ec);
    ec_$init(up_ec);
    ec_$init(rcv_ec);
    ecs[1] := addr(start_ec);
    ecs[2] := addr(stop_ec);
    ecs[3] := addr(down_ec);
    ecs[4] := addr(up_ec);
    ecs[5] := addr(rcv_ec);
    for i := 1 to 5 do
      vals[i] := 1;
    ec_$advance(ready_ec);

    done := false;
    repeat
      case ec_$waitn(ecs, vals, 5) of
        iic_ev_start: begin
          iic_start(line, guardian_status);
          ec_$advance(done_ec);
        end;
        iic_ev_stop: begin
          iic_stop(line, guardian_status);
          ec_$advance(done_ec);
          done := true;
        end;
        iic_ev_down: begin
          ml_$exclusion_start(send_lock);
          if state = iic_line_up then
            state := iic_line_remote_down;
          ml_$exclusion_stop(send_lock);
        end;
        iic_ev_up: begin
          ml_$exclusion_start(send_lock);
          if state = iic_line_remote_down then
            state := iic_line_up;
          ml_$exclusion_stop(send_lock);
        end;
        iic_ev_received: begin
          hdr := iic_$frame_hdr_ptr_t(rcv_hdr);
          slot := 0;
          for i := 1 to type_count do
            with types[i].entry.range do
              if (hdr^.frame_type >= low) and then
                 (hdr^.frame_type <= high) then begin
                slot := i;
                exit;
              end;
          if slot <> 0 then
            if slots[types[slot].entry.slot].open then begin
              bits := iic_$frame_hdr_ptr_t(rcv_hdr)^.flag_bits.flags_07;
              if 3 in bits then
                demux_flag := true;
              pkt.is_local := pkt_$hdr_broadcast in hdr^.flag_bits.info_bits;
              pkt.link_addr.n_words := 2;
              addr_long := addr(pkt.link_addr.addr[0]);
              addr_long^ := hdr^.src_node;
              pkt.frame_type := hdr^.frame_type;
              pkt.data_pa[1] := rcv_data;
              pkt.body_len := rcv_hdr_len - 28;
              pkt.body := 28 + rcv_hdr;
              pkt.unused_24 := 0;
              pkt.data_len := rcv_data_len;
              mac_os_$demux(pkt, iic_port[line], demux_flag, st);
              if st.all <> status_$ok then begin
                netbuf_$rtn_hdr(rcv_hdr);
                pkt_$dump_data(iic_$pages_ptr_t(addr(rcv_data))^, rcv_data_len);
              end;
            end;
        end;
      end;
      vals[1] := ec_$read(start_ec) + 1;
      vals[2] := ec_$read(stop_ec) + 1;
      vals[3] := ec_$read(down_ec) + 1;
      vals[4] := ec_$read(up_ec) + 1;
      vals[5] := ec_$read(rcv_ec) + 1;
    until done;
    proc1_$unbind(guardian_pid, unbind_st);
  end;
end;
