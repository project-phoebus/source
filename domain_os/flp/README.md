# The FLP subsystem in Domain Pascal

The floppy disk driver (the DN3xx's NEC uPD765 class controller and DMA
channel 3).

## Layout

One module, `flp.pas`, `module flp_;` (the map segments' name), in two
code sections and the default data section:

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | 0xAC | FLP_$INT | `[section(wired_proc, wired_data)]` |
| .TEXT | 0x8CC | FLP_$REVALIDATE, flp_format_track, FLP_DO_IO, FLP_$DO_IO, FLP_$CINIT, FLP_$DINIT, FLP_$SHUTDOWN, EXCS, SHAKE | none (the defaults) |

Data: the map's FLP_ data segment, 0x13C bytes in .DATA, the module's
variables (the heading names no section: .text and .data are the
defaults), reached through A5 in .TEXT and by its absolute address from
FLP_$INT.  The defined globals FLP_$EC (+0x60) and FLP_$SREGS (+0x70)
are the map's symbols inside it; `flp.pas` lists every object and who
reads it.  The block starts with the driver's jump table (initialized
with the four entry points' addresses), whose address FLP_$CINIT gives
DISK_$REGISTER.

Routines: every one but flp_format_track has a map symbol and is global
(FLP_DO_IO, EXCS and SHAKE have no `$`); flp_format_track (no symbol) is
module-local, `internal`, top-level (it reads no link and lies right
before its one caller).  None is nested.  No hand assembly.  FLP_DCTE
(which holds FLP_$CINIT's and FLP_$INT's addresses) is the IO manager's
static DCTE, not this unit's.  The constants the fragments pass by
address, and FLP_$DINIT's label record constant, are cells after their
routines' code.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| FLP_$INT | `int.pas` |
| FLP_$REVALIDATE | `revalidate.pas` |
| flp_format_track | `format_track.pas` |
| FLP_DO_IO | `flp_do_io.pas` |
| FLP_$DO_IO | `do_io.pas` |
| FLP_$CINIT | `cinit.pas` |
| FLP_$DINIT | `dinit.pas` |
| FLP_$SHUTDOWN | `shutdown.pas` |
| EXCS | `excs.pas` |
| SHAKE | `shake.pas` |
| (data) | the variables in `flp.pas` |

The SAU8's form (`floppy_atbus`, the floppy controller on the AT bus)
has the same module and sections, a block of its own (the map's FLP_
data segment, 0x1FC bytes in .DATA: the SAU2's objects in their order
with the overrun record, the motor's timer element, spin lock, time and
flags, the overrun page's addresses and the interrupt unit among them),
and four routines more, in its image order:

| routine | fragment |
|---------|----------|
| FLP_$INT | `int.pas` (the arm) |
| FLP_$REVALIDATE | `revalidate.pas` (the arm) |
| FLP_$SHUT_DOWN_MOTOR | `shut_down_motor.pas` (new) |
| SET_FLP_TIMER | `set_flp_timer.pas` (new) |
| FLP_$TURN_MOTOR_ON | `turn_motor_on.pas` (new) |
| FLP_$MOTOR_CALLBACK | `motor_callback.pas` (new) |
| flp_format_track | `format_track.pas` (the arm) |
| FLP_DO_IO | `flp_do_io.pas` (the arm: locked a boolean) |
| FLP_$DO_IO | `do_io.pas` (false for locked) |
| FLP_$CINIT | `cinit.pas` (the arm: the kind-3 DCTE's view) |
| FLP_$DINIT | `dinit.pas` (the arm) |
| FLP_$SHUTDOWN | `shutdown.pas` (the arm) |
| EXCS | `excs.pas` (without the parity and DMA checks) |
| SHAKE | `shake.pas` (a pause before each byte) |

`flp.ins.pas` has the form's ports (the same names for the main status
and the data register, which the shared bodies use), the kind-3 DCTE's
view, the controller slot, the overrun record, the map variables and
the four headings under the part.

## Insert files

- `flp.ins.pas` (new): the driver's status values (flp_$retry, and the
  AT bus form's crash status; bad disk format is disk/disk.ins.pas's), the register block (`[device]`, the main status as a byte
  and as a set; the status and data fields are named main_status and
  data_reg, which do not collide with locals and parameters inside
  `with` statements), the result register word, the command block, the
  controller slot, the sector ID, the label record; FLP_$EC and
  FLP_$SREGS extern; the nine global headings.
- `disk/disk.ins.pas`: the disk statuses FLP returns, disk_$byte_t,
  disk_$device_entry_t, disk_$volume_t (0x48 bytes), disk_$daddr_t and
  disk_$io_req_t (0x40 bytes), the process slot and DISK_BPTBL (the
  map's symbol, the slot of process 1, which the drivers index at -4
  for the pending byte), DISK_$REGISTER's heading.
- `io/io.ins.pas`: dcte_t's longword at 0x3C a variant (its high word is
  FLP_DO_IO's lock number and DISK_$REGISTER's flags), TESTPAGE's
  heading (the map's name for the probe, hand assembly in a data
  segment).
- `dma/dma.ins.pas`: the channel's MAR (0x0C) and MFC (0x29), which FLP
  stores; the filler split around them, no other offset moved.
- Used as they are: `ec/ec.ins.pas` (EC_$INIT, EC_$WAIT,
  EC_$ADVANCE_WITHOUT_DISPATCH), `ml/ml.ins.pas`, `time/time.ins.pas`
  (TIME_$CLOCKH), `mmu/mmu.ins.pas` (MMU_$VTOP), `wp/wp.ins.pas`
  (WP_$WIRE), `parity/parity.ins.pas` (PARITY_$CHK_IO), DMA_$CHECK.

## Open items

### TODO(pascal)

- `dinit.pas`: the 10-byte label record is copied from a constant in the
  code; Domain Pascal has no record constants, so the Pascal stores the
  four fields.

## Named dispatch codes

FLP_$DO_IO's tests of the queue block's operation use
disk/disk.ins.pas's `disk_$req_op_read`, `_write` and `_format_track`
(disk's dispatch-code block).
