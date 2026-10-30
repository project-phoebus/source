{ misc/crash_system.ins.pas - CRASH_SYSTEM, for the Domain Pascal tree.

  What the Pascal files use.  CRASH_SYSTEM and CRASH_SHOW_STRING are
  hand-written assembly in the image (the map's CRASH_SYSTEM data
  segment, 0x2F0 bytes; misc/m68k/crash_system.s), so these are only the
  headings Pascal callers compile against, from how compiled callers
  pass the argument.  Include base/base.ins.pas before it.
}

{ CRASH_SYSTEM: crash the system with a status.  One argument, passed by
  address.  The routine saves SR and all sixteen registers, reads the
  argument slot past them and the return address, and copies the
  longword it points to into its own data.  So the argument is only
  read: `in'.  Its 267 calls in the image all push one address: of a
  local, of a four-byte constant cell after the caller's code, of a
  field, an address parameter passed on, or an address in a register.
  So by address under the default convention.  It returns for some
  statuses (misc/m68k/crash_system.s; TTY_$I_RCV goes on after the
  call).  The type: status_$t is a record (base/base.ins.pas), so a
  status variable fits it but a status constant, an integer32 literal,
  does not (the reference has no record constants).  `univ' admits both;
  a constant passed to a `univ' formal of its own size keeps its type
  (ref 5.3.3), so the cell holds the four bytes of the status.  The
  other heading that fits every caller without `univ' is
  `in status: integer32', with the variables passed as `st.all' (the
  same address).  Which heading the original had is not known. }
procedure crash_system(in status: univ status_$t); extern;

type
  { A crash-console string as CRASH_SHOW_STRING takes it: characters up
    to the `%' that ends it (embedded hex fields, a `%' terminator).  Its
    length is the string's, so the formal is the one-element array of
    tty_$chars_t (tty/tty.ins.pas) passed `univ'. }
  crash_$chars_t = array[1..1] of char;

{ CRASH_SHOW_STRING (hand assembly in the same data segment): saves the
  registers, reads its one argument off the stack, and prints the string
  from that address, never written.  Its compiled callers push one
  address at each of its six calls (DXM_$ADD_CALLBACK, OS_$SHUTDOWN
  three times, OS_$BOOT_ERRCHK, REM_FILE_$SERVER).  So by address under
  the default convention, and `in'; `univ' for strings of any length,
  each passed as its own cell. }
procedure crash_show_string(in str: univ crash_$chars_t); extern;
%if crash_reboot %then

{ CRASH (hand assembly in the same data segment, a map symbol): hand a
  restart code to the PROM, which restarts the node.  It reads the code
  word and the longword after it off the stack, by value (`val_param'),
  and replaces the longword with an address of its own before calling
  the PROM; OS_$SHUTDOWN passes 0 there. }
procedure crash(code: integer; param: integer32);
  options(extern, val_param);

var
  { CRASH_$OK_TO_REBOOT (map symbol in CRASH_SYSTEM's data): whether a
    crash may restart the node, a boolean byte; OS_$INIT sets it at the
    end of a boot without boot flag 15. }
  crash_$ok_to_reboot: extern boolean;
%endif
%if large_vm %then

var
  { SERVER_$FLAG (map symbol in CRASH_SYSTEM's data, a byte): whether
    the node runs as a server, a boolean.  OS_$INIT's node check tests
    it with MMU_$NORMAL_MODE; with the PROM's configuration record
    (`prom_config_record') OS_$INIT sets it from the console's kind. }
  server_$flag: extern boolean;
%endif
