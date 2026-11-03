{ IIC_$OPEN_OS - open a channel for MAC_OS (the driver's open_os).

  Image addresses:
    sau3  0x00E85DDC  IIC_$OPEN_OS

  - At most 6 packet-type ranges.  The channel is copied back on failure
    too.

  Status stored:
    iic_open_internal's status: the channel was opened, or not
    status_$iic_operation_aborted: more than 6 ranges
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                       out status: status_$t);
  options(val_param);
var
  args: iic_$open_args_t;
  st: status_$t;
  i: integer;
begin
  if params.num_pkt_types > 6 then begin
    status.all := status_$iic_operation_aborted;
    return;
  end;
  args.count := params.num_pkt_types;
  for i := 1 to params.num_pkt_types do
    args.types[i] := iic_$range_t(params.pkt_types[i - 1]);
  iic_open_internal(line, args, st);
  status := st;
  params.channel := args.slot;
end;
