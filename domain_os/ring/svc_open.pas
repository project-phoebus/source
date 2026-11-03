{ RING_$SVC_OPEN - open a channel for a user (the driver's svc_open).

  Image addresses:
    sau2  0x00E76DF2  RING_$SVC_OPEN
    sau3  0x00E785E2  RING_$SVC_OPEN
    sau8  0x03C836CA  RING_$SVC_OPEN

  Status stored:
    ring_$open_internal's status: the channel was opened, or not
}

procedure ring_$svc_open(var unit: pinteger; var args: ring_$open_args_t;
                         unused3: integer; var unused4: univ integer32;
                         out status: status_$t);
  options(val_param);
var
  local_status: status_$t;
begin
  ring_$open_internal(false, unit, args, local_status);
  status := local_status;
end;
