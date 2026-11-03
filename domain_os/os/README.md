# The OS subsystem in Domain Pascal

The kernel's start-up and shutdown (OS_$INIT and its helpers, the boot
error check, the display's canned object, the shutdown sequence).

## Layout

The OS_ map names are spread over several map modules; os/ is the home
of two of them and holds fragments for four others.

**`os.pas`, `module os;`** (the map segments' name), one compilation unit
in two code sections and two data sections:

| section | code size | routines (image order) | attribute |
|---------|-----------|------------------------|-----------|
| OS_INIT_PROC | 0x1564 | network_$fetch_diskless_info, prompt_for_yes_or_no, OS_$INIT, OS_$BOOT_ERRCHK | `[section(os_init_proc, os_init_data)]` |
| .TEXT | 0x52C | os_$print_init_error, VTOP_OR_CRASH, os_$free_ppn, os_$free_va_page, os_$start_proc2, OS_$INSTALL_DISPLAY_ASTE, DUMMY_INTERRUPT_HANDLER, OS_$SHUTDOWN, OS_$CHKSUM, OS_$GET_EC | none (the defaults) |

The OS_INIT_PROC routines with data load A5 with the OS_INIT_DATA block
(OS_$INIT, OS_$BOOT_ERRCHK); the .TEXT ones with the .DATA block
(OS_$SHUTDOWN, and OS_$CHKSUM and OS_$GET_EC, which never use it).  The
blocks' contents:

| block | offset | object |
|-------|--------|--------|
| OS, OS_INIT_DATA, 0x188 bytes | +0x000 | OS_$INIT's statics (os/init.pas): mmap_table, 0xE0 bytes, zero (MMAP_$INIT's `out` table); vectors[1..40] at +0xE0, 0xA0 bytes, the exception-vector table (descriptors, each followed by FIM's and SVC's entry addresses, relocated cells) |
| | +0x180 | OS_$BOOT_ERRCHK's static wait_delay |
| OS, .DATA, 0x18 bytes | +0x00 | OS_$BOOT_DEVICE (`define`d), os_$boot_device_t, 8 bytes |
| | +0x08 | `unused_08`, a stand-in (TODO) |
| | +0x0C | OS_$SHUTTING_DOWN_FLAG (`define`d), boolean |
| | +0x10 | OS_$SHUTDOWN's static wait_delay |

Probed with dpc: the records os_$init_vtoce_t (file_uid 0x04, length
0x14, field_74 0x74, acl_uid 0x88, size 0x90), os_$boot_device_t (unit
0x06, size 8) and os_$shutdown_ec_t (tail 0x08) have the image's
offsets.

**`os_wired_start.pas`, `module os_wired_start, , wired_data;`**: the
data map module OS_WIRED_START (WIRED_DATA, 0xC bytes), whose one object
is OS_$SHUTDOWN_EC, an eventcount linked to itself; OS_DATA_WIRED is its
label.

**Fragments for other map modules:**

| routine | map module | fragment | included by |
|---------|-----------|----------|-------------|
| OS_DISK_PROC | VTOC_ (.TEXT) | `disk_proc.pas` | `../vtoc/vtoc.pas` |
| os_term_init | OS_TERM_INIT (OS_INIT_PROC) | `term_init.pas` | `../term/os_term_init.pas` (its forward heading) |
| OS_$GET_REV_INFO | PRINT_BUILD_TIME (.TEXT) | `get_rev_info.pas` | `../misc/print_build_time_.pas` |
| OS_PROC_SHUTWIRED | FILE_ (.TEXT) | `proc_shutwired.pas` | `../file/file.pas` |

**Hand assembly**:

| routine | source |
|---------|--------|
| OS_$DATA_COPY | in NETWORK_ASM; `network/m68k/data_copy.s` |
| OS_$DATA_ZERO | in NETWORK_ASM; `network/m68k/data_zero.s` |
| NULL_LOOP | code in the NULLPROC data segment; `m68k/nullproc.s` |

On the SAU8 (`base/config.ins.pas`) OS_$INIT has seven arms of its
own: `early_as_init` (AS_$INIT before COLD's segment goes),
`boot_flags_diskless` and `boot_flags_server` (NETWORK_$DISKLESS and
SERVER_$FLAG from the boot flags; the SAU7's too), `pbu_wire_at_boot`
(PBU_$WIRE_PBU after the checksums; the SAU7's too), `atbus_int8_dummy`
(AT bus interrupt 8 acquired for DUMMY_INTERRUPT_HANDLER),
`parity_trap_vector_30` (FIM_$PARITY_TRAP on vector 30 too) and
`vector_seg_prot` (MMU_$SET_SEG_PROT for the vector page).  The other
routines are the SAU9's source.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| network_$fetch_diskless_info | `../network/fetch_diskless_info.pas` (internal) |
| prompt_for_yes_or_no | `../misc/prompt_for_yes_or_no.pas` (internal) |
| os_$free_gap_pmaps | `free_gap_pmaps.pas` (internal; `large_address_space` only: SAU7, SAU9) |
| OS_$INIT | `init.pas` (one routine; its vector installation, boot device test and terminal parameters are in-line code) |
| OS_$BOOT_ERRCHK | `boot_errchk.pas` |
| os_$print_init_error | `print_init_error.pas` (internal; forward heading in os.pas) |
| VTOP_OR_CRASH | `vtop_or_crash.pas` |
| os_$free_ppn | `free_ppn.pas` (internal; only with `pft_mmu`) |
| os_$free_va_page | `free_va_page.pas` (internal; its forward heading in os.pas) |
| os_$start_proc2 | `start_proc2.pas` (internal; forward heading in os.pas) |
| OS_$INSTALL_DISPLAY_ASTE | `install_display_aste.pas` (`display_driver` only: every SAU but the SAU3) |
| DUMMY_INTERRUPT_HANDLER | `dummy_interrupt_handler.pas` |
| OS_$SHUTDOWN | `shutdown.pas` |
| OS_$CHKSUM | `chksum.pas` |
| OS_$GET_EC | `get_ec.pas` |
| OS_$INIT_POWER_OFF_CHECK | `init_power_off_check.pas` (`power_off_check` only: SAU3..SAU6) |
| OS_$CHECK_POWER_OFF | `check_power_off.pas` (`power_off_check` only: SAU3..SAU6) |
| (data) | the blocks in `os.pas` and `os_wired_start.pas` |

VTOP_OR_CRASH (OS .TEXT, global, the address a value parameter copied
from its slot) and MMAP_UNWIRED's module-local mmu_$vtop_or_crash
(`../mmu/vtop_or_crash.pas`, the address by value) are two routines with
two names; no module has both.

Headings (`os.ins.pas`): every global takes the default convention but
OS_DISK_PROC and OS_$DATA_COPY/_ZERO (`val_param`).  No routine returns
a pointer, so no D0 parking.

## Insert files

- `os.ins.pas`: the OS module's globals and records (os_$boot_device_t,
  os_$shutdown_ec_t, os_$init_vtoce_t, OS_$INIT's os_$boot_flags_t,
  os_$boot_info_t and os_$diskless_info_t), the shut-down-wired,
  boot-only, layout and STACK labels (extern chars), the headings of
  every global here, and FILE_, PROC1_ headings and statuses under
  `{ TODO(merge) move to ... }`.
- `os.pas` holds AST_ headings under `{ TODO(merge) move to
  ast/ast.ins.pas }` (they use AST_'s and FILE_'s types, which
  os.ins.pas's many users do not include), and DISPLAY1_$UID.
- Shared inserts it extends or uses: asknode, mst, fim, svc, mmu,
  network, proc2, acl, kbd (kbd_$desc_t's handler block and field_10),
  term/os_term_init.pas (`term_$kbd_handlers_view_t`), uid, as.

## Other SAUs

The SAU5's OS is the SAU2's source with parts (`base/config.ins.pas`);
its blocks: OS_INIT_DATA 0x194 bytes (the vector table's 43 cells),
.DATA 0x18, and a WIRED_DATA block of 0x20 bytes; its code: OS_INIT_PROC
0x16B8, .TEXT 0x5B0, WIRED_PROC 0x38.

- OS_$INIT (`init.pas`): `vme_bus` (VME_$INT and VME_$ERR_INT for
  vectors 28, 29; the count a constant), `pbu_driver` (PBU_$TRAP6 for
  trap 6), `tape_boot` (boot device 5; the mode a word set),
  `gpu_driver` (the graphic device id: DISPLAY3_$UID, COLOR2, the
  graphics processor), `disp2_probe` and `color_board` (the second
  display, COLOR_$COLD_INIT), `power_off_check`.
- OS_$SHUTDOWN (`shutdown.pas`): the color boards (`gpu_driver`,
  `color_board`), PBU_$SHUTDOWN (`pbu_driver`), the power down
  (`power_down`, `vme_power_off`, with a dpc workaround: its
  TODO(pascal)).
- OS_$INIT_POWER_OFF_CHECK and OS_$CHECK_POWER_OFF
  (`init_power_off_check.pas`, `check_power_off.pas`): new, the
  SAU3..SAU6's.
- OS_$BOOT_ERRCHK, VTOP_OR_CRASH and the module-local routines: the
  SAU2's code (offsets and layout values only).

The SAU3's OS is the SAU2's source with parts; its blocks:
OS_INIT_DATA 0x188 bytes (the vector table's 40 cells, trap 6
PBU_$TRAP6's), .DATA 0x18 (the restart code at +0xC,
OS_$SHUTTING_DOWN_FLAG at +0xE), WIRED_DATA 0x20; its code:
OS_INIT_PROC 0x1464, .TEXT 0x388, WIRED_PROC 0x38.

- OS_$INIT (`init.pas`): without `display_driver` (the new part, every
  SAU but the SAU3) no SMD_$INIT, TPAD_$INIT, display probe or
  SMD_$INIT_BLINK, the terminal's mode 1 whatever the boot flags, and
  MST_$DISKLESS_INIT's color flag `false`; `lpr_driver` (new, SAU3 and
  SAU4: LPR_$INIT after RING_$GET_ID), `iic_driver` (IIC_$INIT after
  NETWORK_$INIT); `pbu_driver`, `crash_reboot` (the node check's
  restart through MMU_$NORMAL_MODE alone), `power_off_check`,
  `ring_node_id`; no `boot_time_lock`.
- OS_$INSTALL_DISPLAY_ASTE (`install_display_aste.pas`): only with
  `display_driver`; the SAU3's .TEXT has none.
- OS_$SHUTDOWN (`shutdown.pas`): `pbu_driver` and `crash_reboot`
  (existing arms; no source change).
- OS_$INIT_POWER_OFF_CHECK, OS_$CHECK_POWER_OFF, OS_$BOOT_ERRCHK,
  VTOP_OR_CRASH and the module-local routines: the SAU2's (or the
  SAU5's) code, addresses only.

The SAU9's OS is the same source with its parts; its blocks:
OS_INIT_DATA 0x10B0 bytes (MMAP_$INIT's table of 1024 longwords, the
vector table's 42 cells), .DATA 0x18 (the PROM's restart code at +0xC,
OS_$SHUTTING_DOWN_FLAG at +0xE); its code: OS_INIT_PROC 0x166C, .TEXT
0x59C.

- OS_$INIT (`init.pas`): `prom_config_record` (the third parameter, the
  PROM's configuration record: the terminal, the server flag, a tape
  boot, TIME_$SYS_FREQ, IO_$LOG_SELF_TESTS; the clock and process 1
  before PEB_$INIT; NETWORK_$DISKLESS from boot flag 7), `pft_mmu`'s
  other arm (COLD's segment by MMU_$REMOVE_SPECIAL_SEG, the type-4
  protections by MMU_$PAGE_WRITE_BIT and SMAPS, MMU_$PURGE),
  `large_address_space` (COLD's RARS entry, os_$free_gap_pmaps twice),
  `pmmu_page_maps` (the paging loop's page descriptors), `large_vm`
  (MEM_$INIT, SERVER_$FLAG), `fim_nmi` (FIM_$NMI in the table, no
  parity trap store), `smd_display_memory`, `calendar_service_mode`,
  `crash_reboot` (the server's automatic shutdown, CRASH_$OK_TO_REBOOT),
  `vector_alignment_check`; `ring_node_id` and `boot_time_lock` off.
- OS_$SHUTDOWN (`shutdown.pas`): `smd_display_memory` (SMD_$SHUTDOWN),
  `shutdown_kbd_mode` (TERM_$CONTROL), `crash_reboot` (the restart
  through CRASH).
- OS_$INSTALL_DISPLAY_ASTE: `pft_mmu`'s other arm (AST_$ASSOC_IOPPN,
  MMU_$PURGE), `pmmu_page_maps` (the touched pages' descriptors).
- os_$free_va_page: without `pft_mmu` the routine removes the mapping
  by address (MMU_$REMOVE's two-argument form) and clears the page's
  wire count; no os_$free_ppn.
- os_$free_gap_pmaps (`free_gap_pmaps.pas`): new, module-local in
  OS_INIT_PROC before OS_$INIT.
- `os.pas` declares the MMU headings it uses without `pft_mmu` instead
  of including `mmu.ins.pas` (its TODO(pascal)), OS_PMAPS
  (`pmmu_page_maps`), and includes `mst/mst_internal.ins.pas` (SMAPS,
  RARS, MSTE_PAGES, the segment constants).

The SAU4's OS is the same source with its parts; its blocks:
OS_INIT_DATA 0x4A4 bytes (MMAP_$INIT's table of 248 longwords, the
vector table's 47 cells), .DATA 0x18 (the restart code at +0xC),
WIRED_DATA 0x20; its code: OS_INIT_PROC 0x15D4, .TEXT 0x5E8, WIRED_PROC
0x38.  OS is a `-cpu 460` module (OS_$SHUTDOWN's delay loop multiply).

- OS_$INIT (`init.pas`): the vector table without the coprocessor's,
  BSUN's and the signalling NaN's cells (`fp_five_exceptions`), with
  the MMU's faults and the FP ASID exception (`mmu_fault_vectors`) and the
  memory errors' (`ecc_memory`), and the MMU's fault vectors set after
  the bus error's; COLD's segment by MMU_$REMOVE_SPECIAL_SEG and the
  type-4 protections by MMU_$PAGE_WRITE_BIT and the segment map
  entries' protection field, for the wired kernel's segments too
  (`region_mmu`); the paging loop's page map entries not resident
  (`pmmu_page_maps or region_mmu`, the 8192 segments' folded offset);
  no PEB_$INIT or PEB_$LOAD_WCS (`peb_setup` off), no parity trap
  (`memory_parity` off); SERVER_$FLAG from boot flag 1
  (`boot_flags_server`); MEM_$INIT, LPR_$INIT, the second display.
- OS_$SHUTDOWN (`shutdown.pas`): FP_$SAVEP left alone
  (`shutdown_keeps_fp_savep`); the power down through MMU_$SET_CSR
  (`power_off_csr`); COLOR_$SHUTDOWN, PBU_$SHUTDOWN, the restart
  through CRASH (`crash_reboot`).
- OS_$INSTALL_DISPLAY_ASTE: AST_$ASSOC_IOPPN, MMU_$PURGE and the
  touched pages' entries not resident (`region_mmu`).
- OS_$BOOT_ERRCHK, VTOP_OR_CRASH, os_$free_va_page (the form without
  `pft_mmu`), os_$start_proc2 and the other module-local routines:
  existing code, addresses only.

Headings of other modules for these arms are in `os.ins.pas` (SMD_'s
graphic device id, GPU_, COLOR2_, COLOR_, PBU_, DISP2_PRESENT) and
`os.pas` (DISPLAY2_$UID, DISPLAY3_$UID, GPU's register page), each under
its part with a TODO(merge) naming its home; the SAU9's are in their
homes, under their parts: `misc/crash_system.ins.pas` (CRASH,
CRASH_$OK_TO_REBOOT, SERVER_$FLAG), `fim/fim.ins.pas` (FIM_$NMI),
`io/io.ins.pas` (IO_$LOG_SELF_TESTS); the PROM's record is
`os.ins.pas`'s.  The SAU3's LPR_$INIT heading is in `os.ins.pas` under
`lpr_driver`, with a TODO(merge) naming `lpr/lpr.ins.pas`.  `os.pas`
includes `mbus.ins.pas` and `vme.ins.pas` under `vme_bus`, and
`iic/iic.ins.pas` under `iic_driver`.

## Open items

The salvage path of OS_$INIT crashes when MMU_$NORMAL_MODE returns true,
and goes on to ask when it is false; the Pascal follows the image (`if
mmu_$normal_mode then crash_system(status)`).

Names and form:
- OS_$INIT's salvage retry stores the volume number it kept (the same
  number as recomputing it from boot.unit).
- The node message is VFMT_$WRITE2 (VFMT's write entries share one
  address).
- OS_$INIT stores stored_node and prom_node on the unequal path only.
- The longword the map names both NETWORK_$ME and ROUTE_$PORT is
  NETWORK_$ME here.
- OS_$DATA_ZERO is hand assembly in NETWORK_ASM.
- DUMMY_INTERRUPT_HANDLER is a map symbol with no caller.
- os_term_init's map name is the segment's (OS_TERM_INIT), not a
  routine symbol.

### TODO(pascal)

- `os.pas`: the .DATA block's longword at +0x08, held by `unused_08`.
- `proc_shutwired.pas`: OS_PROC_SHUTWIRED's 4 frame bytes.
- `install_display_aste.pas`: OS_$INSTALL_DISPLAY_ASTE's open frame
  bytes, where the register-held locals' slots lie; not probed.
- `init.pas`: OS_$INIT's frame: the two value parameters' copies sit
  among the locals, where dpc puts them first.
- `os.pas`: MMU's headings for the MMU without `pft_mmu` belong in
  `mmu/mmu.ins.pas`.
- `free_gap_pmaps.pas`: first, last and s are a non-negative subrange in
  the image; pinteger until dpc takes that subrange's index.
