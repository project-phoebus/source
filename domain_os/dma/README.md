# The DMA subsystem in Domain Pascal

The MC68450 DMA controller's set-up and completion check.

## Layout

One module, `dma.pas`, `module dma_;` (the map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | DMA_, 0x130 bytes | dma_$init_m68450_channel (module-local), DMA_$INIT, DMA_$CHECK (its jump table and two cells), DMA_$FREE_ASID (an empty procedure), the filler | `[section(wired_proc, wired_data)]` on each |

Data: the map's DMA_ data segment in WIRED_DATA, 4 bytes, zero, no map
symbol, addressed by nothing (TODO in `dma.pas`, TAPE_BOOT's shape).  No
routine loads A5.  The registers are the IODEFS page DMA, an extern
array of four channel records in `dma.ins.pas`.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| dma_$init_m68450_channel | `init_m68450_channel.pas` (`internal`) |
| DMA_$INIT | `init.pas` |
| DMA_$CHECK | `check.pas` (a `case` with a jump table; two constant cells) |
| DMA_$FREE_ASID | `free_asid.pas` (an empty procedure, one word by value) |

`dma.ins.pas`: the register values; the channel record
`dma_$m68450_channel_t` (`[device]`, 0x40 bytes) and its pointer; the
extern `dma`; the three headings.  `disk/disk.ins.pas`: the five
disk-manager statuses DMA_$CHECK uses.

## Against the conformance unit

`../domain-pascal/tests/conformance/dma_init_m68450_channel.pas` (not
modified; byte-identical with the image) is dma_$init_m68450_channel.
The body is the same five statements.  Differences:
- The record: the unit's `m68450_channel_t` ends at the CPR byte (0x2E
  bytes) and has no MTC word; here it is 0x40 bytes (the channels'
  stride, which DMA_$CHECK's indexing shows) with `mtc: integer` at 0x0A
  (which DMA_$CHECK tests), the unit's `pad08` split around it.  The
  offsets the routine stores to are the same.
- The section: `[section(wired_proc, wired_data)]` here, none in the
  unit (the manifest places it).
- Names: the type is `dma_$m68450_channel_t` here; the SAB constant is
  `m68450_ccr_sab` where the unit writes
  `chr(16#10)`.

## Open items

DMA_$CHECK's crash arms leave the result unassigned: the image's result
register is whatever CRASH_SYSTEM left (no caller can see it,
CRASH_SYSTEM does not return for these codes).  Status 0x00080006, for
MC68450 error 16, is "floppy is not 2-sided" in the status database;
kept.

### TODO(pascal)

- `check.pas`: the ERR/ACT tests are bit tests of the zero-extended CSR
  byte in a register, the form of a set member test; the `&` reading is
  not a known form.
- `check.pas`: 4 frame bytes (stand-in `unused_10`).
- `dma.pas`: the 4-byte WIRED_DATA block nothing addresses.
