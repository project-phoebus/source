{ pchist/pchist.ins.pas - PCHIST (the PC histogram profiler) types and
  routine headings, for the Domain Pascal tree.

  What the Pascal files use (sio2681/int.pas, pchist/pchist.pas).
  Apollo's customer insert files of SR10.2 declare nothing of it.  Include
  base/base.ins.pas before it.
}

type
  { The range PCHIST_$CNTL is given: the first and last address of the
    sampled range, read as longwords and compared unsigned, and a
    process number in the word at +8, read and tested as a signed word:
    a positive number is the process, a negative one the negated UNIX
    process id.  What follows the word is not read. }
  pchist_$range_t = record
    first: linteger;                      { 0x00 }
    last: linteger;                       { 0x04 }
    pid: integer;                         { 0x08 }
  end;

  { The system histogram (0x42A bytes; the names of +0x04, +0x08 and
    +0x0A are the ones the image's uses suggest, see
    pchist/README.md).  PCHIST_$CNTL copies it whole to its
    caller, 0x10A longwords and a word, and wires it from +0x000 to
    +0x428.  Who writes and reads each field:
      +0x00 enabled       PCHIST_$CNTL stores 1
      +0x02 doalign       set and cleared: a boolean byte
      +0x04 pid_filter    stored by PCHIST_$CNTL, read by PCHIST_$COUNT
      +0x06 multiplier    stored by PCHIST_$CNTL
      +0x08 shift         stored by PCHIST_$CNTL; PCHIST_$COUNT shifts
                          by it
      +0x0A               never addressed (unused_0a)
      +0x0C range_start   unsigned compares in PCHIST_$COUNT
      +0x10 range_end
      +0x14 bucket_size   stored by PCHIST_$CNTL
      +0x18 total_samples, +0x1C over_range, +0x20 under_range, +0x24
            wrong_pid      cleared by PCHIST_$CNTL, incremented in
                          PCHIST_$COUNT
      +0x28 histogram     (+ 4 * bin), 256 longwords cleared by
                          PCHIST_$CNTL's loop
      +0x428              never addressed but copied (unused_428). }
  pchist_$histogram_t = record
    enabled: integer;                     { 0x000 }
    doalign: boolean;                     { 0x002 }
    pid_filter: integer;                  { 0x004 }
    multiplier: pinteger;                 { 0x006 }
    shift: integer;                       { 0x008 }
    unused_0a: integer;                   { 0x00A }
    range_start: linteger;                { 0x00C }
    range_end: linteger;                  { 0x010 }
    bucket_size: linteger;                { 0x014 }
    total_samples: integer32;             { 0x018 }
    over_range: integer32;                { 0x01C }
    under_range: integer32;               { 0x020 }
    wrong_pid: integer32;                 { 0x024 }
    histogram: array[0..255] of integer32;  { 0x028 }
    unused_428: integer;                  { 0x428 }
  end;

{ PCHIST_$COUNT - record one sample of the program counter. }
procedure pchist_$count(in pc_ptr: linteger; in mode_ptr: integer); extern;

{ PCHIST_$INTERRUPT - record a sample of the program counter from an
  interrupt. }
procedure pchist_$interrupt(in pc: integer32); extern;

{ PCHIST_$INIT - initialize the profiler's exclusion lock. }
procedure pchist_$init; extern;

{ PCHIST_$UNIX_PROFIL_CNTL - turn per-process profiling on or off (UNIX
  profil). }
procedure pchist_$unix_profil_cntl(in cmd_ptr: integer;
                                   in buffer_ptr: linteger;
                                   in bufsize_ptr: linteger;
                                   in offset_ptr: linteger;
                                   in scale_ptr: linteger;
                                   out status_ret: status_$t);
  extern;

{ PCHIST_$UNIX_PROFIL_FORK - give a forked child its parent's profiling. }
procedure pchist_$unix_profil_fork(in child_pid_ptr: integer;
                                   in child_asid_p: integer);
  extern;

{ PCHIST_$CNTL - start, stop or read the system PC histogram. }
procedure pchist_$cntl(in cmd_ptr: integer; in range_ptr: pchist_$range_t;
                       out data_ptr: pchist_$histogram_t;
                       out status_ret: status_$t);
  extern;

{ PCHIST_$UNIX_PROFIL_ADDUPC - count the current process's pending sample
  into its profil() buffer. }
procedure pchist_$unix_profil_addupc; extern;

{ PCHIST_$CNTL's command (the compares `cmd_ptr = 0', `= 1', `= 3' and
  `<> 3'): 0 start profiling with new parameters, 1 stop profiling and
  return the current data, 2 (unused, returns the current data), 3
  start profiling with alignment mode.

  PCHIST_$UNIX_PROFIL_CNTL's command (its `case cmd_ptr of', 0, 1, 2):
  0 enable profiling for the current process, 1 disable it, 2 set the
  overflow pointer.

  No Apollo insert declares them. }
const
  pchist_$cntl_start = 0;
  pchist_$cntl_stop = 1;
  pchist_$cntl_query = 2;
  pchist_$cntl_start_aligned = 3;

  pchist_$profil_enable = 0;
  pchist_$profil_disable = 1;
  pchist_$profil_set_overflow = 2;
