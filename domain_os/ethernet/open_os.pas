{ ETHERNET_$OPEN_OS - open a system channel for MAC_OS.

  Image addresses:
    sau9  0x3C483DCA  ETHERNET_$OPEN_OS

  - The driver record's open_os entry.  MAC_OS's packet-type ranges
    (their low words) become a channel's open arguments of version 2,
    opened with the system's socket; the channel goes back in the
    record's word at +4.
  - The channel is copied back on a failure too (as RING's).

  Status stored:
    ethernet_open's status: the channel was opened, or not
}

procedure ethernet_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                            out status: status_$t);
  options(val_param);
var
  args: ethernet_$open_args_t;
  st: status_$t;
  i: integer;
begin
  args.count := params.num_pkt_types;
  args.version := eth_open_version;
  for i := 1 to params.num_pkt_types do begin
    args.ranges[i].low := params.pkt_types[i - 1].range_low;
    args.ranges[i].high := params.pkt_types[i - 1].range_high;
  end;
  ethernet_open(true, line, args, st);
  status := st;
  params.channel := args.channel;
end;
