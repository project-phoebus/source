{ iic_open_internal - open a channel of a line with its packet-type
  ranges.

  Image addresses:
    sau3  0x00E85C9E  iic_open_internal (module-local)

  - On a line that is up, under its send lock: the first free one of the
    four channels, and the ranges added to the line's table (10 at
    most), each with low <= high and meeting no range already there.
  - The ranges of the request before a refused one stay in the table
    beyond its count.

  Status stored:
    status_$ok: the channel was opened, its number in args.slot
    status_$iic_device_not_acquired: the line is not up
    status_$iic_operation_aborted: no free channel, too many ranges, or
      a range refused
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_open_internal(var line: pinteger; var args: iic_$open_args_t;
                            out status: status_$t);
  internal;
label
  unlock;
var
  slot: pinteger;
  i: integer;
  j: integer;
begin
  status.all := status_$ok;
  with iic_lines[line] do begin
    if state <> iic_line_up then begin
      status.all := status_$iic_device_not_acquired;
      return;
    end;
    ml_$exclusion_start(send_lock);

    slot := 1;
    while slots[slot].open do begin
      if slot >= 4 then begin
        status.all := status_$iic_operation_aborted;
        goto unlock;
      end;
      slot := slot + 1;
    end;

    if type_count + args.count > 10 then begin
      status.all := status_$iic_operation_aborted;
      goto unlock;
    end;
    for i := 1 to args.count do begin
      if (args.types[i].low > args.types[i].high) or else
         iic_range_overlaps(args.types[i].low, args.types[i].high, types,
                            type_count) then begin
        status.all := status_$iic_operation_aborted;
        goto unlock;
      end;
      j := i + type_count;
      types[j].entry.range := args.types[i];
      types[j].entry.slot := slot;
    end;
    slots[slot].asid := proc1_$as_id;
    slots[slot].open := true;
    type_count := type_count + args.count;

unlock:
    ml_$exclusion_stop(send_lock);
    if status.all = status_$ok then
      args.slot := slot;
  end;
end;
