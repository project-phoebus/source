# The WIN_SCSI subsystem in Domain Pascal

The SCSI Winchester disk driver, on the SAUs whose map has the WIN_SCSI_
module (the part `win_scsi_disk`, `../base/config.ins.pas`: the SR10.2
SAU9, the DN2500). Translated from the SAU9 image; the other builds
compile the module to an empty object. It drives its disks through the
SCSI_ driver (`../scsi/`).

## Layout

One compilation unit, `win_scsi.pas`, `module win_scsi_, wired_proc,
wired_data;` (the map segment's name), its whole body under `%if
win_scsi_disk`:

| section | SAU9 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | WIN_SCSI_, 0x18BC bytes | seven module-local routines, then WIN_SCSI_$DINIT .. WIN_SCSI_$DO_SYS_COMMAND | none (the heading's) |
| OS_INIT_PROC | WIN_SCSI_, 0x278 bytes | WIN_SCSI_$CINIT | `[section(os_init_proc, os_init_data)]` |
| WIRED_DATA | WIN_SCSI_ data, 0xD68 bytes | the units, the page list, the sense log, the jump table, the log index | module variables |

The block (`win_scsi.pas` tables it): nine units of 0x160 bytes (a data
buffer, its address, the SCSI handle, the transfer limit, the lock
number, one logical unit of 0x4C bytes, the ready flag), the 32 physical
page addresses of a transfer, a ten-entry log of sense answers, a
longword nothing addresses (a stand-in), the jump table DISK_$REGISTER is
given, and the log index (1).  The DCTEs WIN_SCSI_DCTE_0..7 lie in the
DCTES section (`../io/dctes.pas`, not translated for the SAU9).

## Routines and their fragments

All fifteen are compiled code.

| routine | fragment |
|---------|----------|
| win_scsi_request_sense (local) | `request_sense.pas` |
| win_scsi_check_result (local) | `check_result.pas` |
| win_scsi_command (local) | `command.pas` |
| win_scsi_command_phys (local) | `command_phys.pas` |
| win_scsi_rw_block (local) | `rw_block.pas` |
| win_scsi_set_error_page (local) | `set_error_page.pas` |
| win_scsi_check_error_page (local) | `check_error_page.pas` |
| WIN_SCSI_$DINIT | `dinit.pas` |
| WIN_SCSI_$DO_IO | `do_io.pas` |
| WIN_SCSI_$ERROR_QUE | `error_que.pas` |
| WIN_SCSI_$GET_STATS | `get_stats.pas` |
| WIN_SCSI_$SHUTDOWN | `shutdown.pas` |
| WIN_SCSI_$SPIN_DOWN | `spin_down.pas` |
| WIN_SCSI_$DO_SYS_COMMAND | `do_sys_command.pas` |
| WIN_SCSI_$CINIT | `cinit.pas` |

## Insert files

- `win_scsi.ins.pas` (new): the disk statuses DISK_ does not declare,
  the SCSI operation codes, sense keys, additional sense codes and mode
  pages the driver uses, the sense answer, log entry, statistics,
  logical unit and unit records, the mode, inquiry and capacity views of
  the unit's buffer, WIN_PAGE, the SAU9 forms of three MMU headings (a
  TODO(pascal): their place is `../mmu/mmu.ins.pas`), and the headings.
- `../scsi/scsi.ins.pas` (extended): status_$scsi_dma_overrun, the 6-
  and 10-byte command views of scsi_$cdb_t, and scsi_$info_t's
  max_transfer as linteger (the driver divides it unsigned).
- `../base/config.ins.pas` (extended): the part `win_scsi_disk`.

## Open items

- TODO(pascal) (`win_scsi.ins.pas`): MMU_$REMOVE's SAU4, SAU6..SAU9 form
  (a virtual address and a word) and MMU_$INSTALL, MMU_$CACHE_INHIBIT_VA
  are declared here, not in `../mmu/mmu.ins.pas`.
- WIN_SCSI_$CINIT's second RESERVE (after a unit attention) passes the
  unit's buffer where the first passes none; the length is 0 both times.
- The 16#00880037 crash status (a fixed disk without the format device
  and rigid geometry pages) has no text in the SR10.2 status database.
