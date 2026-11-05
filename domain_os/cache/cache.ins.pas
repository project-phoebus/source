{ cache/cache.ins.pas - CACHE_ (the instruction cache), for the Domain
  Pascal tree.

  What the Pascal files use: the headings of the two hand-written
  routines (cache/m68k/clear.s, cache/m68k/flush_virtual.s), written from
  how their compiled callers call them.
}

{ CACHE_$CLEAR (hand-written, cache/m68k/clear.s): sets the clear bit of
  the cache control register, invalidating the instruction cache.  It
  reads no argument.  Its caller, PARITY_$CHK, pushes nothing and reads
  no register after it (it overwrites D0 next), so a procedure: the
  CACR value the routine leaves in D0 is never read. }
procedure cache_$clear; extern;

{ CACHE_$FLUSH_VIRTUAL (hand-written, cache/m68k/flush_virtual.s: an
  empty routine, a bare return, on the SAU2).  DISK_'s third unit calls
  it with nothing pushed (AS_IO_SETUP, DISK_$AS_XFER_MULTI,
  DISK_$DIAG_IO) and reads no register after it.  A procedure. }
procedure cache_$flush_virtual; extern;

{ CACHE_$ENABLE_PHYSICAL and CACHE_$DISABLE_PHYSICAL (hand-written, in
  MMU_ASM on the SAU7): write the physical cache's register (MMU +
  16#200), 16#E4 and 0.  PARITY_$CHK calls them with nothing pushed
  and reads no register after them.  Procedures. }
procedure cache_$enable_physical; extern;
procedure cache_$disable_physical; extern;
