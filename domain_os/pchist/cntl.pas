{ PCHIST_$CNTL - start, stop or read the system PC histogram.

  Image addresses:
    sau2  0x00E5CDB6  PCHIST_$CNTL
    sau2  0x00E5CD02  pchist_$unwire_cleanup (nested)
    sau2  0x00E5CD66  pchist_$stop_profiling (nested)
    sau8  0x03C66524  PCHIST_$CNTL

  - Commands 0 and 3 start a histogram: 256 bins over the range rounded
    up to a power of two (or the whole address space), and a process
    filter (a negative number a UNIX process id).
  - The histogram is wired and sampling turned on (3 with alignment); 0
    also counts itself as a profiler.
  - Command 1 stops the histogram; every command hands it back.  The
    record handed back has the process filter at +0x04 and the shift at
    +0x08 (pchist/pchist.ins.pas).

  Status stored:
    status_$ok: the command was done
    proc2_$upid_to_uid's or proc2_$get_pid's status: the UNIX process id
      is not a process (the histogram unwired)
}

procedure pchist_$cntl(in cmd_ptr: integer; in range_ptr: pchist_$range_t;
                       out data_ptr: pchist_$histogram_t;
                       out status_ret: status_$t);
var
  uid: uid_$t;
  size: linteger;
  buckets: linteger;
  new_bucket_size: linteger;
  new_multiplier: pinteger;
  i: pinteger;
  new_shift: integer;
  unused_1c: integer;                     { stand-in }
  unused_20: integer32;                   { stand-in }
  unused_22: integer;                     { stand-in }

  { pchist_$unwire_cleanup - turn the histogram off and unwire it.

    Image addresses:
      sau2  0x00E5CD02  pchist_$unwire_cleanup (nested)

    - Only when the histogram is on.  Nested in PCHIST_$CNTL, called by
      its sibling too; its loop index is the parent's i.

    Status stored: none.
}

  procedure pchist_$unwire_cleanup;
  var
    unused_8: integer32;                  { stand-in }
  begin
    if pchist_$histogram_enabled then begin
      pchist_$histogram_enabled := false;
      pchist_$doalign := false;
      for i := 1 to pchist_$wired_count do
        wp_$unwire(pchist_$wire_pages[i]);
      pchist_$wired_count := 0;
    end;
  end;

  { pchist_$stop_profiling - stop the system histogram.

    Image addresses:
      sau2  0x00E5CD66  pchist_$stop_profiling (nested)

    - A counted system profiler is uncounted and, unless PCHIST_$CNTL
      was given command 3, the terminal manager told; the histogram is
      then turned off and unwired.

    Status stored: none.
}

  procedure pchist_$stop_profiling;
  begin
    if pchist_$sys_profiling_count <> 0 then begin
      ml_$exclusion_start(pchist_$lock);
      pchist_$sys_profiling_count := pchist_$sys_profiling_count - 1;
      if cmd_ptr <> pchist_$cntl_start_aligned then
        pchist_$enable_terminal(1);
      ml_$exclusion_stop(pchist_$lock);
    end;

    pchist_$unwire_cleanup;
    pchist_$histogram.doalign := false;
  end;

begin
  status_ret.all := status_$ok;

  if (cmd_ptr = pchist_$cntl_start) or else
     (cmd_ptr = pchist_$cntl_start_aligned) then begin
    pchist_$stop_profiling;

    { the range's size }
    if (range_ptr.first = 0) and then (range_ptr.last = 0) then
      size := 0
    else if range_ptr.last < range_ptr.first then
      size := 512
    else
      size := range_ptr.last - range_ptr.first + 1;

    { the bins }
    if size = 0 then begin
      new_multiplier := 256;
      new_bucket_size := 16#1000000;
      new_shift := 24;
    end
    else begin
      buckets := rshft(size, 8);
      if (size & 16#FF) <> 0 then
        buckets := buckets + 1;
      new_bucket_size := 2;
      new_shift := 1;
      while buckets > new_bucket_size do begin
        new_bucket_size := new_bucket_size * 2;
        new_shift := new_shift + 1;
      end;
      new_multiplier := rshft(size + new_bucket_size - 1, new_shift);
      if new_multiplier = 0 then
        new_multiplier := 256;
    end;

    with pchist_$histogram do begin
      for i := 0 to 255 do
        histogram[i] := 0;

      { the process filter }
      if range_ptr.pid < 0 then begin
        proc2_$upid_to_uid(-range_ptr.pid, uid, status_ret);
        if status_ret.all <> status_$ok then begin
          pchist_$unwire_cleanup;                   { merged with the one below }
          return;
        end;
        pid_filter := proc2_$get_pid(uid, status_ret);
        if status_ret.all <> status_$ok then begin
          pchist_$unwire_cleanup;
          return;
        end;
      end
      else
        pid_filter := range_ptr.pid;

      range_start := range_ptr.first;
      range_end := new_bucket_size * new_multiplier + range_ptr.first - 1;
      multiplier := new_multiplier;
      bucket_size := new_bucket_size;
      shift := new_shift;
      total_samples := 0;
      over_range := 0;
      under_range := 0;
      wrong_pid := 0;
      doalign := true;
      enabled := 1;

      mst_$wire_area(addr(pchist_$histogram), addr(unused_428),
                     pchist_$wire_pages, 3, pchist_$wired_count);
    end;

    pchist_$histogram_enabled := true;
    pchist_$doalign := cmd_ptr = pchist_$cntl_start_aligned;
    data_ptr := pchist_$histogram;

    if cmd_ptr = pchist_$cntl_start then begin
      ml_$exclusion_start(pchist_$lock);
      pchist_$sys_profiling_count := pchist_$sys_profiling_count + 1;
      pchist_$enable_terminal(0);
      ml_$exclusion_stop(pchist_$lock);
    end;
  end

  else begin
    if cmd_ptr = pchist_$cntl_stop then
      pchist_$stop_profiling;
    data_ptr := pchist_$histogram;
    status_ret.all := status_$ok;
  end;
end;
