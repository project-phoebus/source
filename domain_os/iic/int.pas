{ IIC_$INT - the controller's interrupt routine (the PBU unit's
  handler).

  Image addresses:
    sau3  0x00E85686  IIC_$INT

  - The result is 1 when the interrupt is not the driver's or needs no
    eventcount, 3 when the PBU's interrupt routine is to advance the
    eventcount the line's int_ec_ptr now points at.
  - A command's completion advances int_ec.  An event is counted, or,
    for a received frame: the receive buffers are replaced; a frame for
    MAC_OS is kept in the line's record for the guardian (rcv_ec), a
    network packet goes to its socket through NET_IO, a link message
    advances down_ec or up_ec.
  - The interrupt is acknowledged in the control register except for an
    unknown kind.

  Status stored: none.
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
function iic_$int: integer;
var
  data_cell: integer32;
  hdr_cell: integer32;
  line: pinteger;
  hdr: integer32;
  data: integer32;
  hdr_len: pinteger;
  data_len: pinteger;
  kind: integer;
begin
  if not interrupter(line) then begin
    iic_$int := 1;
    return;
  end;
  with iic_lines[line], iic_$control_page[0][line].cb do begin
    unused_02 := 0;
    unused_03 := 0;
    unused_2a := 0;
    unused_2b := 0;
    if int_kind = iic_int_command then begin
      int_ec_ptr^ := addr(int_ec);
      iic_$int := 3;
      csr^.control := iic_csr_ack;
      return;
    end;
    if int_kind <> iic_int_event then begin
      iic_$int := 1;
      int_kind := 0;
      return;
    end;
    int_kind := 0;

    case event of
      7: begin
        counts.events[1] := counts.events[1] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      6: begin
        counts.events[6] := counts.events[6] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      2: begin
        counts.events[2] := counts.events[2] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      4: begin
        counts.events[4] := counts.events[4] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      5: begin
        counts.events[5] := counts.events[5] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      3: begin
        counts.events[3] := counts.events[3] + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      8: begin
        errors.event_8 := errors.event_8 + 1;
        event := 0;
        iic_$int := 1;
        csr^.control := iic_csr_ack;
      end;
      iic_event_received: begin
        case rx_kind of
          iic_rx_packet, iic_rx_message: begin
            kind := rx_kind;
            hdr := rx_hdr_va;
            netbuf_$get_hdr(rx_hdr_pa, rx_hdr_va);
            iic_map_iova(rx_hdr_pa, rx_hdr_iova);
            if rx_data_len = 0 then
              data := 0
            else begin
              data := rx_data_pa;
              netbuf_$get_dat(rx_data_pa);
              iic_map_iova(rx_data_pa, rx_data_iova);
            end;
            hdr_len := rx_hdr_len;
            data_len := rx_data_len;
            rx_hdr_len := 0;
            rx_data_len := 0;
            event := 0;
            csr^.control := iic_csr_ack;
            counts.received := counts.received + 1;
            if 0 in iic_$frame_hdr_ptr_t(hdr)^.flag_bits.info_bits then begin
              int_ec_ptr^ := addr(rcv_ec);
              rcv_hdr := hdr;
              rcv_data := data;
              rcv_hdr_len := hdr_len;
              rcv_data_len := data_len;
              iic_$int := 3;
              return;
            end;
            if kind = iic_rx_packet then
              with pkt_$hdr_ptr_t(hdr)^ do begin
                dest.node := node_$me;
                dest.sock := sock;
              end;
            data_cell := data;
            hdr_cell := hdr;
            if net_io_$put_in_sock_int(3, line, hdr_cell, data_cell, hdr_len,
                                       data_len, int_ec_ptr^) then
              iic_$int := 3
            else
              iic_$int := 1;
          end;
          iic_rx_link: begin
            case rx_code of
              iic_link_down: begin
                int_ec_ptr^ := addr(down_ec);
              end;
              iic_link_up: begin
                int_ec_ptr^ := addr(up_ec);
              end;
            end;
            event := 0;
            csr^.control := iic_csr_ack;
            iic_$int := 3;
          end;
          otherwise begin
            event := 0;
            csr^.control := iic_csr_ack;
            iic_$int := 1;
          end;
        end;
      end;
      otherwise begin
        event := 0;
        csr^.control := iic_csr_ack;
        iic_$int := 1;
      end;
    end;
  end;
end;
