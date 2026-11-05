{ ETHERNET_$SVC_OPEN - open a user channel.

  Image addresses:
    sau6  0x7808904A  ETHERNET_$SVC_OPEN
    sau7  0x3C493754  ETHERNET_$SVC_OPEN
    sau8  0x03C86F50  ETHERNET_$SVC_OPEN
    sau9  0x3C482B50  ETHERNET_$SVC_OPEN

  - The driver record's svc_open entry: ethernet_open for a user, its
    status returned through a local.

  Status stored:
    ethernet_open's status: the open's result
}

procedure ethernet_$svc_open(var unit: pinteger;
                             var args: ethernet_$open_args_t;
                             unused3: integer; var unused4: univ integer32;
                             out status: status_$t);
  options(val_param);
var
  st: status_$t;
begin
  ethernet_open(false, unit, args, st);
  status := st;
end;
