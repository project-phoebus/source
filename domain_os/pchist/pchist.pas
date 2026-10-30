{ pchist/pchist.pas - the PCHIST module, the PC histogram profiler.

  Image addresses:
    sau2  0x00E2C204  PCHIST data (WIRED_DATA, 0x128 bytes)
    sau2  0x00E85718  PCHIST_UNWIRED_D (overlay section, 0x938 bytes)

  One compilation unit, in three code sections and one data section of
  its own, with an overlay section besides: the map's PCHIST code
  segments in WIRED_PROC (0xD8 bytes, PCHIST_$COUNT, PCHIST_$INTERRUPT),
  OS_INIT_PROC (0x14 bytes, PCHIST_$INIT) and .TEXT (0x650 bytes, the
  rest), its PCHIST data segment in WIRED_DATA (0x128 bytes), and the
  load section PCHIST_UNWIRED_D (0x938 bytes).

  The overlay section: PCHIST_UNWIRED_D is a load section with no module
  segment in it, so an overlay section, `var (section_name)' (ref 3.14,
  p. 3-52; 7.2.4, Method 4); every routine reaches it by absolute
  address.  The map's names are cut at 16 characters, so its name may
  be longer.

  The heading: the .TEXT routines' A5 is WIRED_DATA's block, so the
  heading names no code section and wired_data as the data section,
  `module pchist, , wired_data;' (ref 7.1.1, p. 7-2; 2.2.1, p. 2-10).
  The WIRED_PROC routines are headed `[section(wired_proc,
  wired_data)]', PCHIST_$INIT `[section(os_init_proc, os_init_data)]'.

  The WIRED_DATA block, 0x128 bytes, all zero in the image:

    +0x000  pchist_$lock                0x12  the exclusion lock
    +0x012  unused_12                   6     never addressed (stand-in)
    +0x018  pchist_$proc_bitmap         8     a packed array of 64
                                              booleans, by process
    +0x020  pchist_$addr (defined)      0x100 the pending samples,
                                              longwords by process from 1

    +0x120  pchist_$sys_profiling_count 2
    +0x122  pchist_$proc_profiling_count 2
    +0x124  pchist_$histogram_enabled   2     a boolean
    +0x126  pchist_$doalign (defined)   2     a boolean

  The overlay section, 0x938 bytes, all zero in the image:

    +0x000  pchist_$proc_data           0x500 64 records of 0x14 bytes,
                                              by process from 1
    +0x500  pchist_$wire_pages          0xC   3 longwords from 1
    +0x50C  pchist_$histogram           0x42A pchist/pchist.ins.pas
    +0x936  pchist_$wired_count         2

  The routines live in one fragment file each, in image order within
  each section; PCHIST_$CNTL's two nested routines are in its file.
  pchist_$enable_terminal is called by several routines, not only its
  enclosing ones, so it is a top-level `internal' routine.

  Loop alignment: the .TEXT segment aligns its loop heads up to
  pchist_$unwire_cleanup and not from PCHIST_$CNTL on (dpc's
  --loop-align-off-from=PCHIST_$CNTL).

  Build: dpc -I domain_os domain_os/pchist/pchist.pas.  Check:
  tools/pascal_check.sh.
}
module pchist, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'pchist/pchist.ins.pas';

{ The module's own types. }
type
  { A process's profil() parameters, 0x14 bytes: the size, offset and
    scale (unsigned), the overflow pointer and the buffer. }
  pchist_$lint_ptr_t = ^linteger;
  pchist_$proc_t = record
    buffer: linteger;                     { 0x00: an address }
    bufsize: linteger;                    { 0x04 }
    offset: linteger;                     { 0x08 }
    scale: linteger;                      { 0x0C }
    overflow_ptr: pchist_$lint_ptr_t;     { 0x10 }
  end;

  { A word of a profil() buffer (read, and incremented in place). }
  pchist_$word_ptr_t = ^integer;

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  pchist_$count;
  pchist_$interrupt;
  pchist_$init;
  pchist_$unix_profil_cntl;
  pchist_$unix_profil_fork;
  pchist_$cntl;
  pchist_$unix_profil_addupc;

{ The WIRED_DATA block, in the order of its offsets (above); the two map
  symbols defined where they lie (ref 7.2.1, Method 1: the `define'
  allocation clause). }
var
  pchist_$lock: ml_$exclusion_t;              { +0x000 }
  unused_12: array[1..3] of integer;          { +0x012: stand-in }
  pchist_$proc_bitmap: packed array[1..64] of boolean;  { +0x018 }
  pchist_$addr: define array[1..64] of linteger;        { +0x020 }
  pchist_$sys_profiling_count: integer;       { +0x120 }
  pchist_$proc_profiling_count: integer;      { +0x122 }
  pchist_$histogram_enabled: boolean;         { +0x124 }
  pchist_$doalign: define boolean;            { +0x126 }

{ The overlay section (above), in the order of its offsets. }
var (pchist_unwired_d)
  pchist_$proc_data: array[1..64] of pchist_$proc_t;    { +0x000 }
  pchist_$wire_pages: array[1..3] of integer32;          { +0x500 }
  pchist_$histogram: pchist_$histogram_t;                { +0x50C }
  pchist_$wired_count: integer;                          { +0x936 }

{ ---- WIRED_PROC ---- }
%include 'pchist/count.pas';                { PCHIST_$COUNT }
%include 'pchist/interrupt.pas';            { PCHIST_$INTERRUPT }

{ ---- OS_INIT_PROC ---- }
%include 'pchist/init.pas';                 { PCHIST_$INIT }

{ ---- .TEXT ---- }
%include 'pchist/enable_terminal.pas';      { pchist_$enable_terminal }
%include 'pchist/unix_profil_cntl.pas';     { PCHIST_$UNIX_PROFIL_CNTL }
%include 'pchist/unix_profil_fork.pas';     { PCHIST_$UNIX_PROFIL_FORK }
%include 'pchist/cntl.pas';                 { PCHIST_$CNTL, with
                                              pchist_$unwire_cleanup and
                                              pchist_$stop_profiling }
%include 'pchist/unix_profil_addupc.pas';   { PCHIST_$UNIX_PROFIL_ADDUPC }
