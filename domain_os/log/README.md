# The LOG subsystem in Domain Pascal

The error-log subsystem.

## Layout

One module, `log.pas` (map module name `LOG_`), in two code sections:

| section                     | code             | data                  |
|-----------------------------|------------------|-----------------------|
| WIRED_PROC / WIRED_DATA     | LOG_, 0x2C4 bytes | LOG_, 0x1C bytes |
| OS_INIT_PROC                | LOG_, 0x2EC bytes | constant cells inside the code |

The heading is `module log_, wired_proc, wired_data;` and LOG_$INIT is
headed `[section(os_init_proc, os_init_data)]`: the module-level
variables must land in WIRED_DATA, which only the heading can say for
them (ref 7.1.1); `log.pas` gives the evidence.

The data segment has two map symbols, `LOG_$LOGFILE_UID` (+0x00) and
`LOG_$LOGFILE_PTR` (+0x14), so these are `define`d variables (ref 7.2).
`CRASH_$RECORD` and `LOG_$LAST_ENTRY` belong to the CRASH_RECORD
segment, not to this module.

## Routines and their fragments

| routine                 | section      | fragment |
|-------------------------|--------------|----------|
| LOG_$SHUTDN             | WIRED_PROC   | `shutdn.pas` |
| LOG_$UPDATE             | WIRED_PROC   | `update.pas` |
| LOG_$ADD                | WIRED_PROC   | `add.pas` |
| log_$read_internal      | WIRED_PROC   | `read_internal.pas` (module-local) |
| LOG_$READ               | WIRED_PROC   | `read.pas` |
| LOG_$READ2              | WIRED_PROC   | `read2.pas` |
| log_$check_op_status    | OS_INIT_PROC | inside `init.pas`: nested in LOG_$INIT (it reads LOG_$INIT's frame through its dynamic link; its only caller is LOG_$INIT) |
| LOG_$INIT               | OS_INIT_PROC | `init.pas` |
| (data)                  |              | `log.pas` (the WIRED_DATA block) and the constants of `init.pas` (the cells after log_$check_op_status and after LOG_$INIT) |

LOG_$READ's worker, log_$read_internal, is one of the conformance
targets of the compiler project (`../domain-pascal`).

## The SAU6

The SAU6's LOG_ (WIRED_PROC 0x2BC bytes, OS_INIT_PROC 0x2EC, the data
block 0x1C) is the SAU9's code with the SAU6's LOG_$LAST_ENTRY: no SAU6
source.

## The SAU7

The SAU7's LOG_ (WIRED_PROC 0x2BC bytes, OS_INIT_PROC 0x2EC, the data
block 0x1C) is the SAU9's code: no SAU7 source.

## Open items

The `TODO(pascal)` comments of the translation:

- `log/log.pas`: where a variable declared `extern` (log.ins.pas) and
  `define`d in the module is allocated relative to the module's own
  variables; the define and var parts are interleaved in the block's
  order on the reading that it is allocated at its `define`.
- `log/read_internal.pas`: 4 bytes of the worker's frame that nothing
  addresses (stand-in `unused_10`).
- `log/init.pas`: 12 bytes at the bottom of LOG_$INIT's frame that
  nothing addresses (stand-in `unused_58`).
- `file/file.ins.pas`: the object-location record's bytes 0x1C/0x1D as
  one word set (the bit cleared in 0x1D), or a packed record with bit
  fields: not known.

Uncertain choices that are not TODOs: LOG_$ADD's local order (one of
several that fit its frame) and its token as integer32 with
ML_$SPIN_LOCK's result pinteger (ml/ml.ins.pas); `or else` plus plain
`and` in LOG_$INIT's empty-page test; plain record references where a
`with` would give the same code (LOG_$INIT's re-add of the last entry
and the crash record).

Facts of the image a maintainer needs:

- log_$check_op_status tests the LOW word of LOG_$INIT's status,
  Apollo's `code` field.  So it warns, and LOG_$INIT gives up, iff
  `status & 16#FFFF <> 0`: a status whose code is 0 and whose high word
  is non-zero (16#XXXX0000, the fail bit alone included) lets LOG_$INIT
  go on, and one whose high word is 0 and whose code is non-zero
  (16#0000XXXX, e.g. 16#00000005) disables logging.  Every status with both halves
  non-zero (all the real failures, e.g. name_$not_found 16#000E0007
  from NAME_$CR_FILE) and status_$ok behave as expected.
- The path constant has no NUL: its 36 characters are followed by the
  longword 36.
- The vfmt calls are VFMT_$WRITE2's (three arguments; VFMT_$WRITE2,
  VFMT_$WRITE5 and VFMT_$WRITE10 share one entry).
- FILE_$LOCK never addresses its fifth argument; LOG_$INIT passes a
  4-byte local.  Its second and fourth arguments are FILE_$PRIV_LOCK's
  side and local_only (a boolean).
- The spin lock at +0x0C is one integer32, ml_$spin_lock's lock type,
  over 0x0C..0x0F.  The image does not decide its size:
  ML_$SPIN_LOCK/UNLOCK take the address but never touch the lock (hand
  assembly), and nothing addresses 0x0E.
