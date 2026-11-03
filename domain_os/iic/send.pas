{ IIC_$SEND - send a message on a line of the internet interface
  controller.

  Image addresses:
    sau2  0x00E70A9E  IIC_$SEND
    sau3  0x00E71B70  IIC_$SEND

  - Without the driver a stub: the controller is not in the system, and
    the other arguments are never read.
  - With it, at most 512 bytes of header and 1024 of data, on a line
    that is up.  Two sends are at least 1 ms apart: the line's next_send
    is waited for, then set 1 ms after the send.  The header is built in
    the line's transmit header page, the data copied to its data page,
    under the line's send lock.

  Status stored:
    status_$iic_device_not_in_system: without the driver
    status_$network_data_length_too_large: more than 1024 bytes of data
    status_$network_msg_header_too_big: more than 512 bytes of header
    status_$iic_remote_device_not_acquired: the other end is down
    status_$iic_device_not_acquired: the line is free
    pkt_$bld_internet_hdr's or SEND_PACKET's status
}

{ TODO(pascal) IIC_$SEND's packet info record as one constant

  The SAU3 image fills the first 14 bytes of the info record from a
  constant of that size after the routine's code (three longwords and a
  word), as PROC1_$BIND's cpu record (the TODO(pascal) in
  proc1/bind.pas).  The reference has no record constants.  The Pascal
  assigns the seven fields (the same values, other instructions). }

procedure iic_$send(in line: pinteger; in hdr: univ iic_$msg_t;
                    in hdr_len: pinteger; in data: univ iic_$msg_t;
                    in data_len: pinteger; out status: status_$t);
%if iic_driver %then
var
  link: iic_$link_t;
  info: pkt_$info_t;
  wait_st: status_$t;
  now: time_$clock_t;
  st: status_$t;
  timeout: pinteger;
  retry: integer;
  len: integer;
  port: integer;
%endif
begin
%if iic_driver %then
  if data_len > 1024 then begin
    status.all := status_$network_data_length_too_large;
    return;
  end;
  if hdr_len > 512 then begin
    status.all := status_$network_msg_header_too_big;
    return;
  end;
  with iic_lines[line] do begin
    case state of
      iic_line_remote_down: begin
        status.all := status_$iic_remote_device_not_acquired;
        counts.remote_not_acquired := counts.remote_not_acquired + 1;
        return;
      end;
      iic_line_free: begin
        status.all := status_$iic_device_not_acquired;
        return;
      end;
      iic_line_up: begin
        status.all := status_$ok;
      end;
    end;

    time_$abs_clock(now);
    if sub48(next_send, now) then
      time_$wait(time_$relative, next_send, wait_st);
    ml_$exclusion_start(send_lock);
    info.flags := 16#14;
    info.routing_type := 2;
    info.addr_type := 2;
    info.protocol := 16#8031;
    info.retry_limit := 1;
    info.field_0a := 0;
    info.field_0c := 16#FFFF;
    pkt_$bld_internet_hdr(0, 0, 0, 0, 0, 0, info, 0, hdr, hdr_len, data_len,
                          port, iic_$control_page[1][line], len, retry,
                          timeout, st);
    if st.all = status_$ok then begin
      os_$data_copy(data, iic_$control_page[2][line], data_len);
      link.kind := iic_kind_message;
      send_packet(line, tx_hdr_pa, len, tx_data_pa, data_len, link, st);
      time_$abs_clock(next_send);
      add48(next_send, iic_send_spacing);
    end;
    ml_$exclusion_stop(send_lock);
    status := st;
  end;
%else
  status.all := status_$iic_device_not_in_system;
%endif
end;
