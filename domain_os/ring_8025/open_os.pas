{ RING_8025_$OPEN_OS - open a system channel for MAC_OS.

  Image addresses:
    sau8  0x03C8CF96  RING_8025_$OPEN_OS
    sau9  0x3C488B9A  RING_8025_$OPEN_OS

  - The driver record's open_os entry.  MAC_OS's packet-type ranges
    become a channel's open arguments of version 2, each type given the
    SNAP SAP (16#AA) above its low word; the channel takes LLC class 0
    and its frames lose their routing field.  It is opened with the
    system's socket (ring_8025_open_channel), and the channel goes back
    in the record's word at +4, on a failure too.

  Status stored:
    ring_8025_open_channel's status: the channel was opened, or not
}

procedure ring_8025_$open_os(line: pinteger;
                             var params: mac_os_$open_params_t;
                             out status: status_$t);
  options(val_param);
var
  args: ring_8025_$open_args_t;
  st: status_$t;
  i: integer;
begin
  args.count := params.num_pkt_types;
  args.version := r8025_open_version;
  args.llc_class := 0;
  args.strip_rif := 1;
  for i := 1 to params.num_pkt_types do begin
    args.ranges[i].low := params.pkt_types[i - 1].range_low;
    args.ranges[i].low_type.sap := r8025_snap_sap;
    args.ranges[i].low_type.zero := 0;
    args.ranges[i].high := params.pkt_types[i - 1].range_high;
    args.ranges[i].high_type.sap := r8025_snap_sap;
    args.ranges[i].high_type.zero := 0;
  end;
  ring_8025_open_channel(true, line, args, st);
  status := st;
  params.channel := args.channel;
end;
