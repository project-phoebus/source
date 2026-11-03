{ iic_send_link - send a link message, the line's end going down or up.

  Image addresses:
    sau3  0x00E855FA  iic_send_link (module-local)

  - A packet with no header and no data, whose link record carries the
    code (iic_link_down, iic_link_up).

  Status stored:
    iic_command's status: the message was sent, or not
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_send_link(line: pinteger; code: integer;
                        out status: status_$t);
  internal;
begin
  with iic_$control_page[0][line].cb do begin
    tx_hdr_len := 0;
    tx_data_len := 0;
    tx_link.kind := iic_kind_link;
    tx_link.code := code;
  end;
  iic_command(line, iic_cmd_send, status);
end;
