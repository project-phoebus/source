# The misc routines in Domain Pascal

The kernel's routines without `$` that belong to no subsystem directory.

misc/ is not a map module.  Its routines come from seven map modules;
each is a fragment of its own module.  Every routine with a map symbol
is a global, with `$` or without; the two without one are `internal`.

## Layout

| map module | sections | misc/ routines | module file |
|------------|----------|----------------|-------------|
| MEM_LITES | code in WIRED_PROC (0x178 bytes); data in WIRED_DATA (8 bytes) | MEM_LITES, START_MEM_LITES, SET_LITES_LOC (all the module) | `misc/misc.pas`, `module mem_lites, wired_proc, wired_data;` |
| IO_ | code in WIRED_PROC (0x5D0 bytes; and IO_'s others) | CHK | `io/io.pas` (includes `misc/chk.pas`) |
| PRINT_BUILD_TIME | code in .TEXT (0x24C bytes); data in .DATA (0xD0 bytes) | PRINT_BUILD_TIME, GET_BUILD_TIME (OS_$GET_REV_INFO, `../os/get_rev_info.pas`, between them, included there too) | `misc/print_build_time_.pas`, `module print_build_time;` |
| AUDIT | code in WIRED_PROC (0x18 bytes); data in WIRED_DATA (0x20 bytes) (and AUDIT's .TEXT/.DATA segments) | GET_WIRED (the whole WIRED_PROC segment) | `../audit/audit.pas` |
| NAME | code in .TEXT (0x5B0 bytes; and NAME's others) | NAME_CONVERT_ACL_STATUS | `../name/name.pas` |
| AST_ | code in WIRED_PROC (0x6788 bytes) | zero_page (module-local) | `../ast/ast.pas` (`module ast_`) |
| OS | code in OS_INIT_PROC (0x1564 bytes) | prompt_for_yes_or_no (module-local) | `../os/os.pas` |
| CRASH_SYSTEM, DISP_LITES | two D segments (0x2F0 bytes, 0xD4 bytes; hand assembly in data segments) | CRASH_SYSTEM, CRASH_SHOW_STRING, crash_puts_string, the crash report block, DISP_LITES | none: hand assembly (`sau2/*.s`) |

MEM_LITES is the one map module all of whose routines are misc/'s; its
module file is `misc/misc.pas` (found by `tools/pascal_check.sh` as
`<sub>/<sub>.pas`), because `misc/mem_lites.pas` is MEM_LITES's
fragment.  Its data (`misc.pas` lists the offsets): LITES_LOC
(`define`d, +0x00), `mem_lites_row2` (+0x04) and `mem_lites_row1`
(+0x06), module variables, all zero.

PRINT_BUILD_TIME's module file is `misc/print_build_time_.pas`:
`misc/print_build_time.pas` is PRINT_BUILD_TIME's own fragment, so the
module file takes a trailing
underscore (sysbus/atbus_.pas's form, without its reason).  Its module
name is the map's, `print_build_time`; both sections are the defaults,
so the heading names none; OS_$REV and BUILD_$TIME are `define`d module
variables with the image's bytes (OS_$GET_REV_INFO and GET_BUILD_TIME
both reach OS_$REV through A5), and dpc lays them out at +0x00 and
+0xCC.  The map's other symbols there, OS_PROC_UNWIRED,
OS_DATA_UNWIRED and OS_DATA, are section marks the build places
(os/os.ins.pas's extern chars), not the module's.
`tools/pascal_check.sh` finds the file by its `module` heading.

GET_WIRED's WIRED_DATA block is its static (`[section(wired_proc,
wired_data)]`, the routine's own data section, as
DXM_$ADD_SIGNAL_CALLBACK's DATA$ table).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MEM_LITES | `mem_lites.pas` (global) |
| START_MEM_LITES | `start_mem_lites.pas` (global) |
| SET_LITES_LOC | `set_lites_loc.pas` (global) |
| CHK | `chk.pas` (global; in `io/io.pas`) |
| GET_WIRED | `get_wired.pas` (global, `[section(wired_proc, wired_data)]`) |
| PRINT_BUILD_TIME | `print_build_time.pas` (global) |
| GET_BUILD_TIME | `get_build_time.pas` (global) |
| NAME_CONVERT_ACL_STATUS | `name_convert_acl_status.pas` (global) |
| zero_page | `zero_page.pas` (`internal`: no map symbol) |
| prompt_for_yes_or_no | `prompt_for_yes_or_no.pas` (`internal`, `[section(os_init_proc, os_init_data)]`) |
| CRASH_SYSTEM, CRASH_SHOW_STRING, crash_puts_string | none: hand assembly (`m68k/crash_system.s`) |
| CRASH_REPORT and its fields | none: hand-written data (`m68k/crash_report.s`) |
| DISP_LITES | none: hand assembly (`m68k/disp_lites.s`) |
| (data) | LITES_LOC and the two rows in `misc.pas` |

None of the routines is nested.

## Insert files

- `misc/misc.ins.pas`: the lights' pointer type and LITES_LOC; the
  headings of MEM_LITES, START_MEM_LITES, SET_LITES_LOC,
  PRINT_BUILD_TIME, GET_BUILD_TIME and GET_WIRED.
- `misc/crash_system.ins.pas`: CRASH_SYSTEM and CRASH_SHOW_STRING.
- What the fragments use from other insert files: `io/io.ins.pas`
  (CHK's heading, `in ctype: pinteger`, the DCTE's pinteger field),
  `proc1/proc1.ins.pas` (PROC1_$SET_TYPE, PROC1_$UNBIND,
  PROC1_$CREATE_P, a function, `val_param`), `smd/smd.ins.pas`
  (SMD_$LITES), `term/term.ins.pas` (TERM_$READ), `vfmt/vfmt.ins.pas`
  (Apollo's VFMT_$ENCODE2 and VFMT_$ENCODE5), `os/os.ins.pas`
  (`os_$rev_t`, OS_$REV and BUILD_$TIME), `prom/prom.ins.pas`
  (PROM_$MACHINE_ID, read as a word), `name/name.ins.pas` (Apollo's
  name_$file_not_directory, name_$no_rights, name_$insufficient_rights;
  NAME_CONVERT_ACL_STATUS's heading), `acl/acl.ins.pas`
  (status_$no_right_to_perform_operation, status_$acl_wrong_type),
  `ast/ast.ins.pas` (`ast_$page_t` and AST_$ZERO_BUFF).

## Open items

Notes:
- CHK's status 0x00100001 is the database's OS / I/O manager
  "controller not found" (status_$io_controller_not_found).
- AUDIT has two more code segments in .TEXT besides GET_WIRED's.
- MEM_LITES's pad before PROC1_$SET_LOCK is the alignment pad; the
  filler before its loop head aligns it.
- LITES_LOC and SET_LITES_LOC's argument are pointers: the image tests
  them as addresses and dereferences LITES_LOC.
- START_MEM_LITES's message ends with `%.`, VFMT's newline-and-end
  directive.
- GET_BUILD_TIME's `100 - len` is an expression argument with its frame
  temporary, not a variable.

### TODO(pascal)

- `start_mem_lites.pas`: the 10-byte record 8-aligned; the stand-in
  unused_6 holds the bytes above it.
- `get_build_time.pas`: sau held in a register from entry and stored to
  its slot only for the call that passes it (the frame has no room for a
  second variable).
