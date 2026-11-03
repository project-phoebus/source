{ SEND_PACKET - give the controller a packet to send.

  Image addresses:
    sau3  0x00E8554A  SEND_PACKET

  - On a line that is up: the lengths and the link record go into the
    command block, the header page (and a data page when there is data)
    is mapped at the line's transmit I/O addresses, and the send command
    is given.

  Status stored:
    status_$iic_device_not_acquired: the line is free
    status_$iic_remote_device_not_acquired: the other end is down
    iic_command's status: the packet was sent, or not
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure send_packet(in line: pinteger; in hdr_pa: integer32;
                      in hdr_len: integer; in data_pa: integer32;
                      in data_len: pinteger; in link: iic_$link_t;
                      out status: status_$t);
begin
  with iic_lines[line] do begin
    case state of
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
      end;
      iic_line_remote_down: begin
        status.all := status_$iic_remote_device_not_acquired;
      end;
      iic_line_up: begin
        with iic_$control_page[0][line].cb do begin
          tx_hdr_len := hdr_len;
          tx_data_len := data_len;
          tx_link := link;
        end;
        iic_map_iova(hdr_pa, tx_hdr_iova);
        if data_len <> 0 then
          iic_map_iova(data_pa, tx_data_iova);
        iic_command(line, iic_cmd_send, status);
      end;
    end;
  end;
end;
