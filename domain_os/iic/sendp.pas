{ IIC_$SENDP - send a network packet on a line (the driver record's
  sendp).

  Image addresses:
    sau3  0x00E85B96  IIC_$SENDP

  - At most 1024 bytes of data, on a line that is up; the header and
    the first data page are sent as they are.  Two sends are at least
    1 ms apart, as IIC_$SEND's.  The transmit status is 0.

  Status stored:
    status_$network_data_length_too_large: more than 1024 bytes of data
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
    SEND_PACKET's status
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_$sendp(in line: pinteger; hdr_pa: integer32;
                     hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                     in data_pages: univ pkt_$data_pages_t;
                     data_va: integer32; data_len: pinteger;
                     in flags: univ integer;
                     out xmit_status: pinteger;
                     out status_ret: status_$t);
  options(val_param);
var
  send_spacing: static time_$clock_t := [high := 0, low := 250];
  now: time_$clock_t;
  wait_st: status_$t;
  link: iic_$link_t;
begin
  if data_len > 1024 then begin
    status_ret.all := status_$network_data_length_too_large;
    return;
  end;
  xmit_status := 0;
  with iic_lines[line] do begin
    case state of
      iic_line_remote_down: begin
        status_ret.all := status_$iic_remote_device_not_acquired;
        counts.remote_not_acquired := counts.remote_not_acquired + 1;
        return;
      end;
      iic_line_free: begin
        status_ret.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_up: begin
        status_ret.all := status_$ok;
      end;
    end;

    time_$abs_clock(now);
    if sub48(next_send, now) then
      time_$wait(time_$relative, next_send, wait_st);
    ml_$exclusion_start(send_lock);
    link.kind := iic_kind_packet;
    send_packet(line, hdr_pa, hdr_len, data_pages[1], data_len, link,
                status_ret);
    time_$abs_clock(next_send);
    add48(next_send, send_spacing);
    ml_$exclusion_stop(send_lock);
  end;
end;
