{ XPD_$INHERIT_PTRACE_OPTIONS - whether a child inherits the options.

  Image addresses:
    sau2  0x00E5B174  XPD_$INHERIT_PTRACE_OPTIONS

  - Member 3 of flags2.

  Status stored: none.
}

function xpd_$inherit_ptrace_options(in opts: xpd_$ptrace_opts_t): boolean;
begin
  xpd_$inherit_ptrace_options := 3 in opts.flags2;
end;
