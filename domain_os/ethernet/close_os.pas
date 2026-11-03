{ ETHERNET_$CLOSE_OS - close a system channel MAC_OS opened.

  Image addresses:
    sau8  0x03C8823E  ETHERNET_$CLOSE_OS
    sau9  0x3C483E3E  ETHERNET_$CLOSE_OS

  - The driver record's close_os entry: ETHERNET_$SVC_CLOSE on a copy
    of the channel word.

  Status stored:
    ethernet_$svc_close's status: the channel was closed, or not
}

procedure ethernet_$close_os(line: pinteger; var callback_data: integer;
                             out status: status_$t);
  options(val_param);
var
  st: status_$t;
  channel: pinteger;
  unread: integer;
begin
  channel := callback_data;
  ethernet_$svc_close(line, channel, 0, unread, st);
  status := st;
end;
