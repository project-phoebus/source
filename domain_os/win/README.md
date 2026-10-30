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

`win.ins.pas` has the SAU5's window, descriptor and drive records, its
statuses and commands, its map variables and its SEEK, RESTORE,
RETRY_DATA_CHECK and WIN_$DINIT headings under the part.  Open: dpc
refuses the window's record assignments (RESTORE, SEEK,
win_$ecc_correct; their TODO(pascal)), so `win.pas` does not compile
for the SAU5 yet; the other SAUs' WIN_ drivers (TODO(sau)).

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
  walk with adjacent words merged; the field stores are the reading.

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
