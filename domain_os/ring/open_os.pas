{ RING_$OPEN_OS - open a channel for MAC_OS (the driver's open_os).

  Image addresses:
    sau2  0x00E77BA0  RING_$OPEN_OS
    sau3  0x00E79390  RING_$OPEN_OS

  - At most 16 packet-type ranges, opened with the system's socket.
  - The channel is copied back on failure too (the request's word at
    +4).

  Status stored:
    ring_$open_internal's status: the channel was opened, or not
    status_$ring_invalid_svc_packet_type: more than 16 ranges
}

procedure ring_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                        out status: status_$t);
  options(val_param);
var
  args: ring_$open_args_t;
  st: status_$t;
  i: integer;
begin
  if params.num_pkt_types > 16 then begin
    status.all := status_$ring_invalid_svc_packet_type;
    return;
  end;

  args.version := 1;
  args.count := params.num_pkt_types;
  for i := 1 to params.num_pkt_types do
    args.types[i] := ring_$pkt_range_t(params.pkt_types[i - 1]);

  ring_$open_internal(true, line, args, st);
  status := st;
  params.channel := args.channel;
end;
