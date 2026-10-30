{ XPD_$RESET_PTRACE_OPTS - clear a ptrace option record.

  Image addresses:
    sau2  0x00E5B156  XPD_$RESET_PTRACE_OPTS

  Status stored: none.
}

procedure xpd_$reset_ptrace_opts(out opts: xpd_$ptrace_opts_t);
begin
  opts.flags := [];
  opts.signal_mask := [];
  opts.flags2 := [];
  opts.trace_range_lo := 0;
  opts.trace_range_hi := 0;
end;
