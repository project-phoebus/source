# The WIN subsystem in Domain Pascal

The Winchester disk driver (the DN3xx's ANSI-command disk controller on
DMA channel 3: the drive's command, status and seek registers, the
transfer's DMA programming, the retries and the drive's
re-initialization). See `../flp/README.md` for the floppy driver of the
same shape.

## Layout

One module, `win.pas`, `module win_, wired_proc, wired_data;` (the map
segments' name), in two code sections and one data section:

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | WIN_, 0xCFC bytes | wait_for_controller, win_$ansi_command, win_$sense_general_status, win_$check_disk_status, read_or_write_disk_record, win_$reinit_drive, SEEK, win_$format_track, WIN_$DO_IO, DISK_INIT, WIN_$SPIN_DOWN, WIN_$INT, WIN_$DINIT, WIN_$ERROR_QUE, WIN_$GET_STATS | none (the heading's) |
| OS_INIT_PROC | WIN_, 0x98 bytes | WIN_$CINIT | `[section(os_init_proc, os_init_data)]` |

Data: the map's WIN_ data segment, 0x78 bytes in WIRED_DATA, through A5
in the WIRED_PROC routines, by its address in WIN_$CINIT (zero but the
jump table, the longword 1 at +0x68 and -1 in the words at +0x72 and
+0x74):

| offset | variable | type |
|--------|----------|------|
| +0x00 | `win_units` | array[0..0] of win_$unit_t (12 bytes: the DCTE, the register block, the lock word, the unit word) |
| +0x0C | `unused_0c`, a stand-in (win.pas's TODO) | integer32 |
| +0x10 | `win_jump_table` | array[0..6] of univ_ptr: WIN_$SPIN_DOWN, nil, WIN_$DINIT, nil, WIN_$DO_IO, WIN_$ERROR_QUE, WIN_$GET_STATS |
| +0x2C | `unused_2c`, a stand-in | integer32 |
| +0x30 | `win_unit_ec` | array[0..0] of ec_$eventcount_t |
| +0x3C | `unused_3c`, a stand-in | integer32 |
| +0x40 | WIN_$CNT (`define`d, map symbol) | win_$cnt_t (22 bytes) |
| +0x56 | 2 bytes: the next longword's alignment | |
| +0x58 | `win_status` | integer32 |
| +0x5C | `win_dev_info` | win_$vol_ptr_t |
| +0x60 | `win_cur_req` | disk_$io_req_ptr_t |
| +0x64 | WIN_$KTHUNKD (`define`d, map symbol) | integer32 |
| +0x68 | `win_total_blocks` | integer32 := 1 |
| +0x6C | WIN_$ATTN (`define`d, map symbol) | win_$attn_t |
| +0x6E | WIN_$CSTAT (`define`d, map symbol) | pinteger |
| +0x70 | WIN_$SENSE (`define`d, map symbol) | win_$sense_t |
| +0x72 | `win_cur_head` | integer := -1 |
| +0x74 | `win_cur_cyl` | integer := -1 |
| +0x76 | `win_flag` | boolean |
| +0x77 | 1 byte: the block's rounding to 4 | |

The defined variables' names are the map's.  WIN_DCTE (in the DCTES data
segment) is the IO manager's static DCTE, not this unit's (as FLP_DCTE);
WIN_ECC_BUF (DISK_BUFFERS) is named by no WIN_ routine; WIN_VEC is the
disk vector; WIN (IODEFS) is the controller's base, which WIN_DCTE
holds.

Routines: nine globals, every map symbol of the two code segments
(SEEK and DISK_INIT have no `$`); seven module-local (`internal`, no map
symbol), wait_for_controller, win_$ansi_command,
win_$sense_general_status, win_$check_disk_status,
read_or_write_disk_record, win_$reinit_drive and win_$format_track.
None is nested (none reads a static link), none is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| wait_for_controller | `wait_for_controller.pas` |
| win_$ansi_command | `ansi_command.pas` |
| win_$sense_general_status | `sense_general_status.pas` |
| win_$check_disk_status | `check_disk_status.pas` |
| read_or_write_disk_record | `read_or_write_disk_record.pas` |
| win_$reinit_drive | `reinit_drive.pas` |
| SEEK | `seek.pas` |
| win_$format_track | `format_track.pas` |
| WIN_$DO_IO | `do_io.pas` |
| DISK_INIT | `disk_init.pas` |
| WIN_$SPIN_DOWN | `spin_down.pas` |
| WIN_$INT | `int.pas` |
| WIN_$DINIT | `dinit.pas` |
| WIN_$ERROR_QUE | `error_que.pas` |
| WIN_$GET_STATS | `get_stats.pas` |
| WIN_$FILL_CTL_BUF (SAU7, SAU8, WIN_ASM) | none: hand assembly, `m68k/win_asm.s` |
| WIN_$EMPTY_CTL_BUF (SAU7, SAU8, WIN_ASM) | none: hand assembly, `m68k/win_asm.s` |
| WIN_$CINIT | `cinit.pas` |
| (data) | the variables in `win.pas`; the literal cells of the code are the constants passed by address (`chr(0)`, the status constants, `0`) |

The SAU5's driver (`win_descriptor_ctlr`, the descriptor-list
controller) is the other arm of `win.pas`'s data and include list, and
of these fragments' bodies, in its image order:

| routine | fragment |
|---------|----------|
| win_$check_disk_status | `check_disk_status.pas` (the arm) |
| win_$ecc_correct | `ecc_correct.pas` (new) |
| win_$command | `command.pas` (new) |
| RESTORE | `restore.pas` (new) |
| win_$format_track | `format_track.pas` (the arm) |
| SEEK | `seek.pas` (the arm: another heading) |
| RETRY_DATA_CHECK | `retry_data_check.pas` (new) |
| WIN_$DO_IO | `do_io.pas` (the arm) |
| WIN_$DINIT | `dinit.pas` (the arm: another heading) |
| WIN_$SPIN_DOWN | `spin_down.pas` (the arm) |
| WIN_$INT | `int.pas` (the arm) |
| WIN_$ERROR_QUE, WIN_$GET_STATS | the SAU2's code |
| WIN_$CINIT | `cinit.pas` (the arm) |

The SAU8's driver (`win_atbus_ctlr`, the WIN8_ driver of a controller
on the AT bus) is the third arm of `win.pas`, with a block of its own
(the map's WIN_ data segment, 0x380 bytes in WIRED_DATA) and the map's
WIN_ code segments in WIRED_PROC (0xF40 bytes) and OS_INIT_PROC (0x18C
bytes, WIN_$CINIT), in its image order:

| routine | fragment |
|---------|----------|
| WIN_$SPIN_DOWN | `spin_down.pas` (the arm) |
| win_$wait_phase | `wait_phase.pas` (new) |
| win_$send_command | `send_command.pas` (new) |
| win_$check_status | `check_status.pas` (new) |
| win_$format_track | `format_track.pas` (the arm) |
| win_$read_mfg_badspots | `read_mfg_badspots.pas` (new) |
| WIN8_$DO_IO | `win8_do_io.pas` |
| WIN8_$DINIT | `win8_dinit.pas` |
| WIN8_$INT | `win8_int.pas` |
| WIN8_$ERROR_QUE | `win8_error_que.pas` |
| WIN8_$GET_STATS | `win8_get_stats.pas` |
| WIN_$FILL_CTL_BUF, WIN_$EMPTY_CTL_BUF | none: hand assembly, `m68k/win_asm.s` |
| WIN_$CINIT | `cinit.pas` (the arm: another heading) |

Its block, zero but where noted:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `win_stats` | the two drives' statistics, 24 bytes apart (win_$stats_slot_t: the 22-byte record and a pad word) |
| +0x030 | `unused_030`, a stand-in (win.pas's TODO) | 704 bytes |
| +0x2F0 | `win_units` | array[0..1] of win_$unit_t (the DCTE, the ports, 4 bytes) |
| +0x308 | `win_jump_table` | WIN_$SPIN_DOWN, nil, WIN8_$DINIT, nil, WIN8_$DO_IO, WIN8_$ERROR_QUE, WIN8_$GET_STATS |
| +0x324 | `unused_324` | integer32 |
| +0x328 | `win_unit_ec` | array[0..1] of ec_$eventcount_t |
| +0x340 | WIN_$CNT (`define`d, map symbol) | win_$stats_t, addressed by nothing |
| +0x358 | `win_page_pmape` | WIN_PAGE's page table entry's address |
| +0x35C | `win_hdr` | the header pointer of a read's first request |
| +0x360 | `win_buf` | the page's address WIN_ASM is given |
| +0x364 | `win_cmd` | win_$cmd_t, the command block |
| +0x36C | `win_total_blocks` | integer32 := 1 (addressed by nothing here) |
| +0x370 | `win_unit_bits` | integer := 16#2800, DISK_$REGISTER's units |
| +0x372 | `win_last_phase`, `win_last_status` | the phase a time-out waited for, the port's value |
| +0x376 | `win_sector_size` | 256 or 512 (a reporting controller's) |
| +0x378 | `win_max_count` | the sectors of a run: 7, or 31 for a reporting controller |
| +0x37A | `win_count` | the sectors of the run, then those done before an error |
| +0x37C | `win_params_reported` | boolean: the controller reports the drive |

The SAU7's WIN_ (`win_mailbox_ctlr` with `win_atbus_ctlr`) is the
SAU8's with the WIN7_ driver beside it: up to two controllers on the AT
bus that take 64-byte command blocks through mailboxes in memory, each
with its interrupt through IO_$ACQUIRE and a DMA_ channel in cascade
mode, its DCTEs WIN7_DCTE_0 and WIN7_DCTE_1 (io/dctes.pas) and its own
jump table.  The map's WIN_ code segments: WIRED_PROC (0x2DD4 bytes) and
OS_INIT_PROC (0x4BC bytes); the WIN7_ routines come first in each, in
this image order:

| routine | fragment |
|---------|----------|
| win7_$move_iopb (module-local) | `move_iopb.pas` |
| WIN7_$DINIT | `win7_dinit.pas` |
| WIN_SETUP_IOPB | `win_setup_iopb.pas` |
| WIN_SETUP_MAILBOX | `win_setup_mailbox.pas` |
| WIN_SEND_COMMAND | `win_send_command.pas` |
| WIN7_$GET_STATS | `win7_get_stats.pas` |
| get_buffer, wait_buffer, free_buffer (nested in WIN7_$DO_IO) | `win7_do_io.pas` |
| WIN7_$DO_IO | `win7_do_io.pas` |
| WIN7_$ERROR_QUE | `win7_error_que.pas` |
| win7_$move_iopb, save_params, free_buffer (nested in WIN7_$INT) | `win7_int.pas` |
| WIN7_$INT | `win7_int.pas` |
| WIN_$SPIN_DOWN .. WIN8_$GET_STATS | the SAU8's fragments |
| WIN_$FILL_CTL_BUF, WIN_$EMPTY_CTL_BUF | none: hand assembly, `m68k/win_asm.s` |
| WIN7_$CINIT | `win7_cinit.pas` |
| WIN_$CINIT | `cinit.pas` (the SAU8's arm) |

The SAU8's routines are the same source on the SAU7; only the block's
offsets differ.  The block (the map's WIN_ data segment, 0xECC bytes in
WIRED_DATA) has the WIN7_ variables first and between the SAU8's, zero
but where noted:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `win7_bufs` | the 16 transfer windows' bus addresses (a stack, `win7_buf_index` its next) |
| +0x040 | `win7_mbox_ec` | eventcount: an outgoing mailbox free |
| +0x050 | `win7_init_ec` | eventcount: the drive parameters' block done |
| +0x060 | `win7_sg` | a format's sector table, 28 two-byte slots |
| +0x098 | `win7_iopb_base` | the two controllers' command blocks' addresses |
| +0x0A0 | `win7_infos` | the 18 command blocks' records of each controller, 28 bytes each |
| +0x490 | `win7_pages` | the headers' page numbers of a run |
| +0x510 | `win7_ppns` | the data's page numbers of a run |
| +0x590 | `win7_ctlrs` | the two records' addresses (WIN_$CB's elements) |
| +0x598 | `unused_598`, a stand-in (win.pas's TODO) | 56 bytes, the word 16#420 at +0x2C |
| +0x5D0 | WIN_$CB (`define`d, map symbol) | array[0..1] of win7_$ctlr_t, the DMA channels 7 and 3 |
| +0xAD0 | the SAU8's block from `win_stats` to `win_units` | as the SAU8's +0x000..+0x307 |
| +0xDD8 | `win7_jump_table` | WIN_$SPIN_DOWN, nil, WIN7_$DINIT, nil, WIN7_$DO_IO, WIN7_$ERROR_QUE, WIN7_$GET_STATS |
| +0xDF8 | the SAU8's block from `win_jump_table` to WIN_$CNT | as its +0x308..+0x357 |
| +0xE48 | `win7_map_base_2`, `_1`, `win7_map_total`, `win7_map_size`, `win7_cur_req`, `win7_window_base`, `win7_mbox_pa`, `win7_map_left` | the I/O map regions, the request being sent |
| +0xE68 | the SAU8's `win_page_pmape` .. `win_total_blocks` | as its +0x358..+0x36F |
| +0xE80 | `win7_iopb_size`, `win7_mbox_areas`, `win7_mbox_size`, `win7_buf_index` | words |
| +0xE88 | the SAU8's `win_unit_bits` .. `win_count` | as its +0x370..+0x37B; both drivers register `win_unit_bits` |
| +0xE94 | `win7_params_ok`, `win7_first_cinit` := true, `win7_first_dinit` := true | booleans, a word apart |
| +0xE9A | the SAU8's `win_params_reported` | |
| +0xE9C | six time_$clock_t delays: 15, 15, 65, 20, 50 and 15 ticks | |

Its types (`win.ins.pas`, under `win_mailbox_ctlr`): the commands, the
operations, the status and interrupt bits and the completion codes as
named constants; the command block (variants for the transfer and for
the drive parameters' reply), the driver's record of a block, the
mailboxes, the ports, a drive's and a controller's records; WIN_$CB and
RAW_BUF; the WIN7_ and WIN_SETUP_ headings.  `iomap/iomap.ins.pas` gives
IOMAP_$MAP, IOMAP_$UNMAP and the map's word array at MAST_ENBL_REG;
`ml/ml.ins.pas` the statistics lock (`ml_$win_stats_lock`).

The SAU4's driver (`win_ring_disk_ctlr`, the disk controller of the
ring/disk board: up to four drives on a PRIAM or an SMD interface, two
DMA channels of the board's DMA controller through IOMAP's entries 64
and 65) is the fourth arm of `win.pas`, with its block (the map's WIN_
data segment, 0x80 bytes in WIRED_DATA) and the map's WIN_ code
segments in WIRED_PROC (0xFB0 bytes) and OS_INIT_PROC (0x188 bytes,
WIN_$CINIT), in its image order:

| routine | fragment |
|---------|----------|
| seek (module-local; SEEK on the SAU2) | `seek.pas` (the arm: another heading) |
| read_or_write_disk_record | `read_or_write_disk_record.pas` (the arm: another heading) |
| win_$format_track | `format_track.pas` (the arm) |
| WIN_$DO_IO | `do_io.pas` (the arm) |
| DISK_INIT | `disk_init.pas` (the arm: another heading) |
| WIN_$SPIN_DOWN | `spin_down.pas` (the arm) |
| WIN_$INT | `int.pas` (the arm) |
| WIN_$DINIT, WIN_$ERROR_QUE, WIN_$GET_STATS | the SAU2's code |
| WIN_$CINIT | `cinit.pas` (the arm) |

Its block, zero but where noted:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `win_cyls` | array[0..3] of pinteger, each drive's cylinder |
| +0x08 | `win_units` | array[0..0] of win_$unit_t, with the smd_interface bit |
| +0x14 | `unused_14`, a stand-in (win.pas's TODO) | integer32 |
| +0x18 | `win_jump_table` | WIN_$SPIN_DOWN, nil, WIN_$DINIT, nil, WIN_$DO_IO, WIN_$ERROR_QUE, WIN_$GET_STATS |
| +0x34 | `unused_34`, a stand-in | integer32 |
| +0x38 | `win_unit_ec` | array[0..0] of ec_$eventcount_t |
| +0x44 | `unused_44`, a stand-in | integer32 |
| +0x48 | WIN_$CNT (`define`d, map symbol) | win_$cnt_t |
| +0x60 | `win_status` | integer32 |
| +0x64 | `win_dev_info` | win_$vol_ptr_t |
| +0x68 | `win_cur_req` | disk_$io_req_ptr_t |
| +0x6C | `win_hdr_iomap`, `win_data_iomap` | IOMAP's entries 64 and 65 (WIN_$CINIT) |
| +0x74 | `win_total_blocks` | integer32 := 1 |
| +0x78 | `win_cur_drive` | pinteger, the drive last selected |
| +0x7A | `win_flag` | boolean, a seek under way |
| +0x7C | WIN_$STS (`define`d, map symbol) | integer32, addressed by nothing |

Its types (`win.ins.pas`, under the part): the board's disk registers
(`[device]`, the names of the Domain Engineering Handbook's chapter 8,
"RING/DISK"), the PRIAM commands and status bits, the controller status
bits and the disk control values as named constants, the unit word's
smd_interface, the SMD drive's information record; WIN_$CNT and
WIN_$STS; DISK_INIT's heading.  `pbu/pbu.ins.pas` gives IOMAP,
`sysbus/sysbus.ins.pas` SYSBUS_$DEFINE_INT, `ring/ring.ins.pas`
RING_$SEND_NULL.  There is no PARITY_ or DMA_ call.

Its types (`win.ins.pas`, under the part): the ports (`[device]`), the
command block, the sense bytes and the drive parameters as packed
records with their bit fields, the label information, a buffer
address's page number, the kind-3 DCTE's view (io/dctes.pas WIN8_DCTE),
the controller record, the statistics; WIN_$CNT, WIN_PAGE and the
WIN_ASM headings; the commands and phases as named constants.  The
PARITY_ routines are parity/parity.ins.pas's with the channel and two
pages (`parity_dma_page_pairs`).

`win.ins.pas` has the SAU5's window, descriptor and drive records, its
statuses and commands, its map variables and its SEEK, RESTORE,
RETRY_DATA_CHECK and WIN_$DINIT headings under the part.  Open: dpc
refuses the window's record assignments (RESTORE, SEEK,
win_$ecc_correct; their TODO(pascal)), so `win.pas` does not compile
for the SAU5 yet.

The SAU6's WIN_ (`win_descriptor_ctlr` with `win_vectored_ctlr` and
`win6_ct6_board`) is the SAU5's driver for the turbo boards' form of
the descriptor-list controller (the configuration word 16#1B05, its
interrupt defined on the DCTE's vector, WIN_$INT answering false
without the controller's interrupt bit; `large_vm`'s win_$ecc_correct;
no `memory_parity` check in WIN_$DO_IO) with the WIN6_ driver of the
second board's controller beside it.  The map's WIN_ code segments:
WIRED_PROC (0x1C78 bytes) and OS_INIT_PROC (0x388 bytes); the WIN6_
routines come after WIN_$INT and after WIN_$CINIT, in this image order:

| routine | fragment |
|---------|----------|
| WIN6_$GET_IOPBS | `win6_get_iopbs.pas` |
| WIN6_$RTN_IOPBS | `win6_rtn_iopbs.pas` |
| win6_$epb_status (module-local) | `epb_status.pas` |
| WIN6_$GET_ERROR_INFO | `win6_get_error_info.pas` |
| win6_$send_iopb (module-local) | `send_iopb.pas` |
| WIN6_$INT | `win6_int.pas` |
| LOG_INT_ERROR | `log_int_error.pas` |
| WIN6_$ASYNC_INT | `win6_async_int.pas` |
| WIN6_$CTLR_INT | `win6_ctlr_int.pas` |
| WIN6_$DINIT | `win6_dinit.pas` |
| WIN6_$DO_IO | `win6_do_io.pas` |
| send_cmd, ecc_fix, return_iopbs (nested in WIN6_$ERROR_QUE) | `win6_error_que.pas` |
| WIN6_$ERROR_QUE | `win6_error_que.pas` |
| WIN_$ERROR_QUE, WIN_$GET_STATS | the SAU5's fragments |
| WIN_$CINIT | `cinit.pas` (the SAU5's arm) |
| WIN6_$CINIT | `win6_cinit.pas` |

Its block (the map's WIN_ data segment, 0xD54 bytes in WIRED_DATA),
zero but where noted:

| offset | variable | type |
|--------|----------|------|
| +0x000 | WIN6_$INT_ERS (`define`d, map symbol) | the controller's other interrupts' words, a ring of 40 |
| +0x050 | WIN6_$EPBS (`define`d) | the error blocks' copies, a ring of 64 |
| +0x850 | WIN6_$ERRORS (`define`d) | the error counts of the two severities |
| +0x968 | `win6_drives` | the two drives' records, 280 bytes each |
| +0xB98 | RQ (`define`d) | the start queue, 128 block numbers |
| +0xC98 | `win_units` .. `unused_cf4` | the SAU5's +0x00..+0x3F, with the WIN6_ jump table at +0xCA8 (WIN_$SPIN_DOWN, nil, WIN6_$DINIT, nil, WIN6_$DO_IO, WIN6_$ERROR_QUE, WIN_$GET_STATS) and a stand-in after it |
| +0xCF8 | WIN_$CNT (`define`d) | as the SAU5's |
| +0xD10 | WIN6_$FIXES (`define`d) | the corrected data checks |
| +0xD14 | `win6_free_count`, `win6_free_head`, `win6_free_tail` | the free list |
| +0xD1C | `win6_page` | the board's page |
| +0xD20 | WIN_$FIXES .. `win_total_blocks` | as the SAU5's +0x58..+0x67 |
| +0xD30 | WIN_$DT (`define`d) | the command blocks' address and their bus address (DUMP and CRASH_SYSTEM read it) |
| +0xD38 | WIN6_$INT_ERX, WIN6_$EPBX, WIN6_$RETRIES := 10 (`define`d) | |
| +0xD3E | `win6_init_mode` | 2 or 0, after the initialization |
| +0xD40 | RQND, RQST, RQCNT (`define`d) | the queue's tail, head and count |
| +0xD46 | `win_config` .. `win_stat` | as the SAU5's +0x70..+0x77 |
| +0xD4E | WIN6_$FIX_ECCC := true, CTL_BSY (`define`d) | booleans |

Its types (`win.ins.pas`, under `win6_ct6_board`): the board's page
(`[device]`: the command blocks, the mailbox flags and words, the
initialization bytes), the command and error block with its
parameters' variants, the error counts, the drive's record, WIN_$DT,
the label information; the operations, states, severities, classes and
actions as named constants; the map symbols' variables and the WIN6_
headings.  WIN6_$CINIT's heading is io/io.ins.pas's.  CT6_ (ct/) uses
the same page and the free list.

Headings (`win.ins.pas`): WIN_$DO_IO, WIN_$SPIN_DOWN, WIN_$INT and
WIN_$CINIT the default convention (every argument by address, as FLP's
entries); SEEK, DISK_INIT, WIN_$DINIT, WIN_$ERROR_QUE and WIN_$GET_STATS
`val_param` (words and a byte by value).  The module-local routines take
their words by value (`internal`); win_$ansi_command's input byte is
`in` and `univ` (passed by address, a constant from every caller).  No
routine returns a pointer, so no D0 parking.

## Insert files

- `win.ins.pas`: the four statuses only this driver returns, the
  drive's `[device]` register block, the unit record, the statistics
  block, the general status and report records, the geometry words, the
  volume pointer, the five map-symbol variables, the nine global
  headings.
- `disk/disk.ins.pas`: disk_$io_req_ptr_t (`^disk_$io_req_t`) and
  DISK_$SORT's heading (`in vol`, `in out queue`).
- `dma/dma.ins.pas`: the channel's BTC (0x1A word), BAR (0x1C longword)
  and BFC (0x39 byte), which read_or_write_disk_record stores.
- `ec/ec.ins.pas`: EC_$NIL_EC (the eventcount at address 0, map symbol
  in ABSOLUTE), whose address the EC_$WAIT callers push for an unused
  entry.
- Used as they are: `io/io.ins.pas` (dcte_t, TESTPAGE), `ml/ml.ins.pas`,
  `time/time.ins.pas` (TIME_$CLOCKH), `mmu/mmu.ins.pas` (for parity),
  `parity/parity.ins.pas` (PARITY_$CHK_IO), `misc/crash_system.ins.pas`,
  DMA_$CHECK, DISK_$REGISTER, DISK_BPTBL.

## Open items

### Facts worth knowing

- WIN_$INT raises the priority to 5 and never restores it.  It runs
  only as the DCTE's interrupt routine, called by DISK_INTERRUPT from
  io_$flih_dispatch, which has already set IPL 7; WIN_$INT lowers it to
  5, and PROC1_$INT_EXIT, through FIM_$EXIT's return from exception,
  restores the interrupted SR (the hand assembly in io/m68k/,
  proc1/m68k/ and fim/m68k/).
- WIN_$SPIN_DOWN is jump table entry +0x00 (DISK_$SPIN_DOWN calls
  through +0x00).  Its result is a word, which is all its caller
  compares.
- WIN_$ERROR_QUE is a procedure (an empty frame, no result register),
  though the jump table's other entries are functions.
- read_or_write_disk_record's request field at +0x14 is the page number
  (shifted by 10 into BAR, as FLP_DO_IO shifts the same field,
  disk_$io_req_t ppn).
- The block has room for one unit record and one eventcount (the jump
  table at +0x10, WIN_$CNT at +0x40), not arrays of them.

### TODO(pascal)

- `win.pas`: the block's three open longwords (+0x0C, +0x2C, +0x3C),
  stand-ins; an 8-byte alignment from the block's start would explain
  all three.
- `ansi_command.pas`, `read_or_write_disk_record.pas`, `seek.pas`,
  `format_track.pas`, `disk_init.pas`: eight frame bytes each;
  `reinit_drive.pas`: twelve; `int.pas`: four (stand-ins).
- `get_stats.pas`: the zero record's fill, written through a pointer
  walk with adjacent words merged; the field stores are the reading
  (WIN8_$GET_STATS has the same fill).
- `win.pas` (AT bus form): the block's 704 bytes at +0x30 nothing
  addresses, a stand-in.
- `win.ins.pas` (AT bus form): the statistics array's 24-byte elements
  of a 22-byte record, a wrapper record with a pad word.
- `win.pas` (mailbox form): the block's 56 bytes at +0x598, the word
  16#420 at their +0x2C, a stand-in.

### Facts worth knowing (mailbox form)

- WIN_$CB's records index their processes' array from 0x54 bytes in,
  as the image does (process 1's record at 0x54): the records of
  processes 1 to 5 share the bytes of the lists' heads and the fields
  after them.
- WIN7_$INT takes an incoming mailbox number of 0 to 62; the incoming
  mailboxes are 62 (0 to 61).
- WIN7_$ERROR_QUE stores no result; WIN7_$CINIT stores none for a
  controller already set up.
- The routines nested in WIN7_$DO_IO and WIN7_$INT are copies of each
  other (free_buffer) and of the module-level win7_$move_iopb
  (WIN7_$INT's, which shadows it there): the image has the code twice
  and three times, and the copies carry one name.

The SAU2 frames: win_$check_disk_status,
WIN_$DO_IO, WAIT_FOR_CONTROLLER, WIN_$SPIN_DOWN, WIN_$DINIT,
WIN_$GET_STATS and WIN_$CINIT are explained exactly by their locals,
result variables and temporaries; win_$sense_general_status exactly
with the result variable between locals, and DISK_INIT so with its
stand-in (dpc puts the result last, so its offsets of the objects below
differ by 4).

### win_$regs_t's pad

`win_$regs_t`'s pad after param is three chars, pad_03.._05, not a
3-char array, which would be word aligned (ref 3.10.5.5) and move
status, cylinder, head, mode and go by 2; status is at 0x06, cylinder
0x08, head 0x0A, mode 0x0C, go 0x0E, the size 0x10, the image's.

## Named dispatch codes

WIN_$DO_IO's and read_or_write_disk_record's tests of the queue block's
operation use disk/disk.ins.pas's `disk_$req_op_write` and
`_format_track` (disk's dispatch-code block).
