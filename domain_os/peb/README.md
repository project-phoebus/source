# The PEB subsystem in Domain Pascal

The Performance Enhancement Board (the Apollo floating-point board with
its writable control store) and the MC68881 save area, in Domain Pascal,
as `tty/`, `win/` and the others are: the board's set-up and probe at
boot, the microcode load and verify, the per-address-space register save
and load, the context switch when a process touches the board's page,
the flags report and the process cleanup.

## Layout

Three modules, one file each, after the map segments' names: there is
no PEB module in the map, so there is no `peb.pas` (as `ec/` has no
`ec.pas`).  `tools/pascal_check.sh` finds the three by their `module`
headings.

| module file | heading | section | code | routines (image order) | attribute |
|-------------|---------|---------|------|------------------------|-----------|
| `peb_parity.pas` | `module peb_parity, wired_proc, wired_data;` | WIRED_PROC | 0x38 | PEB_$TEST_PARITY_ERR | none (the heading's) |
| `peb_unwired.pas` | `module peb_unwired;` | OS_INIT_PROC | 0x5F8 | PEB_$INIT, peb_$write_wcs, peb_$read_wcs, the nested check, PEB_$LOAD_WCS | `[section(os_init_proc, os_init_data)]` |
| | | .TEXT | 0x200 | PEB_$ASSOC, _$DISSOC, _$GET_STATUS, _$LOAD_REGS, _$UNLOAD_REGS, _$GET_FP, _$PUT_FP | none |
| `peb_wired.pas` | `module peb_wired;` | .TEXT | 0x22C | PEB_$TOUCH, peb_$cleanup_internal, PEB_$GET_INFO | none |
| | | PROC2_DELETE_PRO | 0x20 | PEB_$PROC_CLEANUP | `[section(proc2_delete_pro, proc2_delete_dat)]` |
| (PEB_WIRED_END) | | .TEXT | 4 | none: 4 zero bytes holding the marker PEB_$WIRED_PROC_END (as NETLOG's) | |
| (PEB_ASM) | hand assembly | WIRED_DATA | 0x88 (a data segment) | PEB_$STATUS_REG, PEB_$INT, PEB_$DISP_INT_ADDR (`m68k/int.s`) | none: hand assembly |

Without `peb_board` (base/config.ins.pas; the SAUs with only an
MC68881/68882, the SAU9 translated) the map has PEB_PARITY's data
alone, PEB_UNWIRED's OS_INIT_PROC segment (0x1D8 bytes: PEB_$INIT and
PEB_$LOAD_WCS for the save area, its nested check) and data, PEB_WIRED's
.TEXT segment of 0x60 bytes (PEB_$TOUCH a constant false, PEB_$GET_INFO),
PEB_WIRED_END, and PEB_$PROC_CLEANUP empty; no PEB_ASM, no PEB_$REGS.
The board's routines and `m68k/int.s` are compiled only with
`peb_board`.

Data (every block zero in the image):

| module | block | object | type |
|--------|-------|--------|------|
| PEB_PARITY | 0x24 bytes (WIRED_DATA, through A5) | PEB_$INFO (`define`d, map symbol) | peb_$info_t, 0x22 bytes, the block rounded to 4 |
| PEB_UNWIRED | 4 bytes (.DATA, by its address from OS_INIT_PROC) | M68881_EXISTS (`define`d, map symbol without `$`) | boolean, the block rounded to 4 |
| PEB_WIRED | 0x658 bytes (.DATA, through A5) | PEB_$REGS (`define`d, map symbol; also PEB_$WIRED_DATA_START) | array[0..57] of peb_$fp_state_t (0x1C each) |

The markers PEB_$WIRED_PROC_START (= PEB_$TOUCH), PEB_$WIRED_PROC_END,
PEB_$WIRED_DATA_START (= PEB_$REGS) and PEB_$WIRED_DATA_END (= AUDIT's
first byte) are labels the build places, extern chars in `peb.ins.pas`
(netlog's form).  The board's pages are the map's IODEFS symbols PEB_CTL
(the control page with the WCS window at +0x800, a `[volatile]` record),
PEB_$M_CTRL_PAGE, PEB_$M_DCMD_PAGE (read as a register page) and
PEB_$M_CS_PAGE; the private register page at 16#7000 is a constant
pointer (no relocation).  The trap-page cells are PEB_VEC (0x70) and
the line-F vector, element 11 of TRAP_PAGE (no map symbol at 0x2C).

Routines: thirteen globals (every PEB_ map symbol of the compiled code
segments); three module-local (`internal`, no map symbol):
peb_$write_wcs, peb_$read_wcs and peb_$cleanup_internal (the last loads
A5 itself: its caller is in another section); one nested,
PEB_$LOAD_WCS's check (it reads its static link).  PEB_$INT is hand
assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PEB_$TEST_PARITY_ERR | `test_parity_err.pas` |
| PEB_$INT | none: hand assembly (PEB_ASM, transcribed in `m68k/int.s`) |
| PEB_$INIT | `init.pas` |
| peb_$write_wcs | `write_wcs.pas` (with the page selection inline) |
| peb_$read_wcs | `read_wcs.pas` |
| peb_$load_wcs_check_err | `load_wcs.pas` (nested in PEB_$LOAD_WCS, before it in the image) |
| PEB_$LOAD_WCS | `load_wcs.pas` |
| PEB_$ASSOC | `assoc.pas` |
| PEB_$DISSOC | `dissoc.pas` |
| PEB_$GET_STATUS | `get_status.pas` |
| PEB_$LOAD_REGS | `load_regs.pas` |
| PEB_$UNLOAD_REGS | `unload_regs.pas` |
| PEB_$GET_FP | `get_fp.pas` |
| PEB_$PUT_FP | `put_fp.pas` |
| PEB_$TOUCH | `touch.pas` |
| peb_$cleanup_internal | `cleanup_internal.pas` |
| PEB_$GET_INFO | `get_info.pas` |
| PEB_$PROC_CLEANUP | `proc_cleanup.pas` |
| (data) | the variables of the three module files; PEB_ASM's interrupt status is hand-written data, the crash status a constant cell after PEB_$TOUCH (`peb_fpu_is_hung_err`) |

Headings (`peb.ins.pas`): every global is the default convention
(arguments by address; most have none).  No routine returns a pointer
that a caller parks in D0.

## Insert files

- `peb.ins.pas`: around its one earlier heading, PEB_$GET_STATUS,
  which is unchanged (its one user, `fim/fim.pas`, checks): the PEB
  statuses (but status_$peb_interrupt, which `fim/fim.ins.pas` already
  declares), the crash status, GET_INFO's set members, the board's types
  (the control word, the WCS entry and header, the control page, the
  register page, the saved state), PEB_$INFO's record, the variables
  (PEB_$INFO, M68881_EXISTS, PEB_$REGS, the markers, the board's pages,
  PEB_VEC and TRAP_PAGE), and the headings of every PEB_ map symbol in
  map order.
- `fim/fim.ins.pas` (appended): Apollo's fault_$eccu and
  fault_$wcs_parity (TEST_PARITY_ERR's statuses), FIM_$UII and
  FIM_$FLINE (their addresses are stored into the line-F vector).
- `mmu/mmu.ins.pas` (appended): MMU_$INSTALL_PRIVATE, MMU_$INSTALL's
  heading.
- `vfmt/vfmt.ins.pas` (appended): Apollo's VFMT_$WRITE5.
- `file/file.ins.pas` (appended): FILE_$CREATE.
- `fp/fp.ins.pas`: FP_$SAVEP.
- Used as they are: `ec`, `misc/crash_system`, `proc1`, `ml`, `sysbus`,
  `dma`, `io` (TESTPAGE), `name` (NAME_$RESOLVE), `mst` (MST_$MAPS,
  _$MAP, _$UNMAP, _$WIRE_AREA).

## Open items

### Names and forms

- 16#0012000F is Apollo's fault_$eccu, "uncorrectable memory error
  detected" (stcode.db.10.2, fault.ins.pas), not a "no parity error"
  status, and 16#0012001B is fault_$wcs_parity, "PEB WCS parity error".
- The control word's page field (bits 4..9) is merged as a packed
  record's field.
- The register names: the routine that writes 0x94, 0x98, 0x1B0, 0x1B4
  (PEB_$LOAD_REGS) gives them DATA_OUT and STAT_OUT, the one that reads
  0x8C, 0x90, 0x1D0, 0x1D4 DATA_IN and STAT_IN; the status at 0xF4 is
  both written and read.  Kept as names.
- PEB_$TOUCH compares its argument unsigned (a non-negative longword).
- PEB_$GET_STATUS returns the status's longword (integer32), stored
  into a status's `all`.
- PEB_$TOUCH calls MMU_$INSTALL_PRIVATE on both paths of its owner test
  (two copies in the image).
- PEB_$INFO is one record (SMD reaches its +0x1A off the symbol).
- The 19 page steps of PEB_$LOAD_WCS's save-area arm read nothing; the
  Pascal keeps a page-pair pointer (see the TODO).

### TODO(pascal)

- `load_wcs.pas`: the 19-step page loop of the save-area arm (the
  source construct).
- `touch.pas`: PEB_$TOUCH's frame (the `with` temporaries and the
  result variable against 20 bytes).
- `proc_cleanup.pas`: PEB_$PROC_CLEANUP's frame (four bytes
  unexplained).

The SAU2 frames explained exactly: PEB_$INIT,
peb_$write_wcs and _$read_wcs, the nested check, PEB_$LOAD_WCS (in
declaration order with the register-held locals' slots and the
expression temporary last), PEB_$ASSOC and _$DISSOC (the `with`
temporary), PEB_$GET_STATUS (the result below the locals),
PEB_$LOAD_REGS and _$UNLOAD_REGS, peb_$cleanup_internal.
