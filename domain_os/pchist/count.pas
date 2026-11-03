{ PCHIST_$COUNT - record one sample of the program counter.

  Image addresses:
    sau2  0x00E1A134  PCHIST_$COUNT
    sau4  0x0F81AD9C  PCHIST_$COUNT

  - In mode 1, a profiled process with no sample pending gets the pc as
    its pending sample (pchist_$addr) and a trace fault, which runs
    PCHIST_$UNIX_PROFIL_ADDUPC.
  - When the system histogram is on, the sample is counted: against the
    process filter, below or above the range, or into its bin.
  - The bitmap's element pid is the packed boolean array's (ref 3.11.4.2,
    Table 3-5: one bit per boolean, the first element in the high bit).

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure pchist_$count(in pc_ptr: linteger; in mode_ptr: integer);
var
  pid: integer;
  bin: integer;
  unused_8: integer32;                    { stand-in }
begin
  pid := proc1_$current;

  if mode_ptr = 1 then
    if pchist_$proc_bitmap[pid] then
      if pchist_$addr[pid] = 0 then begin
        pchist_$addr[pid] := pc_ptr;
        fim_$deliver_trace_fault(proc1_$as_id);
      end;

  if pchist_$histogram_enabled then
    with pchist_$histogram do begin
      total_samples := total_samples + 1;
      if (pid_filter = 0) or else (pid = pid_filter) then begin
        if pc_ptr < range_start then
          under_range := under_range + 1
        else if pc_ptr > range_end then
          over_range := over_range + 1
        else begin
          bin := rshft(pc_ptr - range_start, shift);
          histogram[bin] := histogram[bin] + 1;
        end;
      end
      else
        wrong_pid := wrong_pid + 1;
    end;
end;
