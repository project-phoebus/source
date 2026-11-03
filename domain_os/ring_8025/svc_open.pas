{ RING_8025_$SVC_OPEN - open a user channel.

  Image addresses:
    sau8  0x03C8BD86  RING_8025_$SVC_OPEN
    sau9  0x3C48798A  RING_8025_$SVC_OPEN

  - The driver record's svc_open entry: ring_8025_open_channel for a
    user, its status returned through a local.

  Status stored:
    ring_8025_open_channel's status: the open's result
}

procedure ring_8025_$svc_open(var unit: pinteger;
                              var args: ring_8025_$open_args_t;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(val_param);
var
  st: status_$t;
begin
  ring_8025_open_channel(false, unit, args, st);
  status := st;
end;
