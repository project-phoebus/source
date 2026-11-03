{ IIC_$INT_STATISTICS - return a line's counters for NET_IO (the driver
  record's get_stats and get_stats2).

  Image addresses:
    sau3  0x00E72050  IIC_$INT_STATISTICS

  - IIC_$STATISTICS into the caller's buffer; the length is the record's
    56 bytes, 0 when it fails.  max_len is not read.

  Status stored:
    IIC_$STATISTICS's status: the counters were returned, or not
}

procedure iic_$int_statistics(in line: pinteger; stats_buf: univ_ptr;
                              max_len: integer; out length_ret: integer;
                              out status_ret: status_$t);
  options(val_param);
type
  iic_stats_ptr_t = ^iic_$stats_t;
begin
  iic_$statistics(line, iic_stats_ptr_t(stats_buf)^, status_ret);
  if status_ret.all = status_$ok then
    length_ret := 56
  else
    length_ret := 0;
end;
