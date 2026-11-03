{ RING_$CLOSE_OS - close a channel MAC_OS opened (the driver's close_os).

  Image addresses:
    sau2  0x00E77C24  RING_$CLOSE_OS
    sau3  0x00E79414  RING_$CLOSE_OS
    sau8  0x03C844F2  RING_$CLOSE_OS

  - RING_$SVC_CLOSE on a copy of the channel word.

  Status stored:
    ring_$svc_close's status: the channel was closed, or not
}

procedure ring_$close_os(line: pinteger; var callback_data: integer;
                         out status: status_$t);
  options(val_param);
var
  st: status_$t;
  channel: pinteger;
  unread: integer;
begin
  channel := callback_data;
  ring_$svc_close(line, channel, 0, unread, st);
  status := st;
end;
