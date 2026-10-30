{ misc/misc.ins.pas - the routines of misc/ (the kernel's routines
  without `$' that belong to no subsystem directory), for the Domain
  Pascal tree.

  The MEM_LITES module's variable and routines, and PRINT_BUILD_TIME's,
  GET_BUILD_TIME's and GET_WIRED's headings.  CRASH_SYSTEM's, CHK's and
  NAME_CONVERT_ACL_STATUS's are in misc/crash_system.ins.pas,
  io/io.ins.pas and name/name.ins.pas; misc/README.md maps the
  routines to their map modules.

  Include base/base.ins.pas and vfmt/vfmt.ins.pas before it.
}

type
  { The status lights' two words in display memory (LITES_LOC's
    target): MEM_LITES reads the first and the second word through the
    pointer and passes each to SMD_$LITES.  pinteger, SMD_$LITES's
    pattern (smd/smd.ins.pas). }
  misc_$lites_t = array[1..2] of pinteger;
  misc_$lites_ptr_t = ^misc_$lites_t;

var
  { LITES_LOC (map symbol, the first object of the map's MEM_LITES data
    segment in WIRED_DATA): where the lights are, nil when they are off.
    Tested as a longword in memory, and assigned from an address register
    tested against nil, then dereferenced: a pointer.  Defined in
    misc/misc.pas. }
  lites_loc: extern misc_$lites_ptr_t;

{ MEM_LITES - the status-lights process: redraw the lights every 125 ms. }
procedure mem_lites; extern;

{ START_MEM_LITES - place the light rows and start the lights process. }
procedure start_mem_lites; extern;

{ SET_LITES_LOC - set where the status lights are. }
procedure set_lites_loc(loc: misc_$lites_ptr_t); extern;

{ PRINT_BUILD_TIME - write the kernel's banner on the console. }
procedure print_build_time; extern;

{ GET_BUILD_TIME - format the kernel's identification line. }
procedure get_build_time(out buf: univ vfmt_$string_t; out len: integer);
  extern;

{ GET_WIRED - the address of the AUDIT module's wired block. }
function get_wired: univ_ptr; extern;
