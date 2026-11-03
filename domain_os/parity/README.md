# The PARITY subsystem in Domain Pascal

Memory parity error handling.

The module's body is under `memory_parity` (`../base/config.ins.pas`):
the SAU4 has none of it (its memory corrects errors, `../mem/`), and
its module file compiles to an empty object.

## Layout

One module, `parity.pas`, `module parity, wired_proc, wired_data;` (the
map segments' name):

| section    | code           | routines | attribute |
|------------|----------------|----------|-----------|
| WIRED_PROC | 0x354 bytes | PARITY_$CHK (0x302 of code, the filler, two cells), PARITY_$CHK_IO (0x48) | none (the heading's) |
| WIRED_PROC (SAU9) | 0x3EC bytes | PARITY_$CHK (0x358: 0x34E of code, the filler, two cells), PARITY_$CHK_IO (0x3E), PARITY_$SET_STATE (0x56) | none (the heading's) |

Data: the map's 4-byte PARITY data segment in WIRED_DATA, one map
symbol, a `define`d variable of the module (ref 7.2.2, Method 2; extern
in `parity.ins.pas`), zero in the image:

| offset | variable | type | notes |
|--------|----------|------|-------|
| +0x00 | `parity_$during_dma` (PARITY_$DURING_DMA) | boolean | stored and cleared as a byte through A5 |
| +0x01 | (3 bytes) | | the block rounded to a longword |

With `parity_dma_pages` (the SAU9's 0x18C bytes):

| offset | variable | type | notes |
|--------|----------|------|-------|
| +0x00 | `parity_$dma_table` (PARITY_$DMA_TABLE) | array[0..2] of `parity_$dma_chan_t` | 0x84 bytes a channel: 32 page numbers, the count (+0x80), the flag (+0x82) |

With `parity_dma_page_pairs` (the SAU8's 0x24 bytes):

| offset | variable | type | notes |
|--------|----------|------|-------|
| +0x00 | `parity_$dma_table` (PARITY_$DMA_TABLE) | array[0..2] of `parity_$dma_chan_t` | 0x0C bytes a channel: two page numbers, a flag for each (+0x08, +0x09) |

On the SAU8 (`parity_cpu_status`, `parity_dma_page_pairs`; WIRED_PROC
0x320 bytes: PARITY_$CHK 0x29C, PARITY_$CHK_IO 0x48, PARITY_$SET_STATE
0x3C) PARITY_$CHK reads the CPU status register's word at MMU, the page
from MMU_$PARITY_PPN, and turns bit 0 of the CPU control register's
privilege byte off around the scan of PAR_BUFF's 256 longwords
(MMU_$PID_PRIV's copy of it); PARITY_$INFO is a `[device]` there
(`parity.ins.pas`).  The registers are declared in `parity.pas` (the
MMU symbol's layout differs from mmu/mmu.ins.pas's).  PARITY_$CHK_IO
and PARITY_$SET_STATE take the channel and two page numbers.

The state both routines work on, PARITY_$INFO (0x14 bytes), is a map
symbol inside the hand-written FIM's data (FIM_WIRED), so it is an
extern variable in `parity.ins.pas`, not this module's.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PARITY_$CHK | `chk.pas` (three forms: the SAU2, `parity_err_regs`, `parity_cpu_status`; no nested or module-local routine; labels and `goto`s; two constant cells) |
| PARITY_$CHK_IO | `chk_io.pas` (the SAU2, the `parity_dma_pages` and the `parity_dma_page_pairs` bodies) |
| PARITY_$SET_STATE | `set_state.pas` (`parity_dma_pages`, `parity_dma_page_pairs`) |
| (data) | PARITY_$DURING_DMA is the define statement of `parity.pas`; the two status cells after PARITY_$CHK are fault_$parity and fault_$spurious_parity, passed to CRASH_SYSTEM as constants |

`parity.ins.pas`: parity_scratch_prot; the 8-byte address pair
`parity_$err_addrs_t` (copied whole into the log entry); PARITY_$INFO's
type and the extern variable; the log entry; PARITY_$DURING_DMA;
PAR_BUFF (an IODEFS map symbol, the scratch page); the two headings,
`function parity_$chk: boolean` and `function parity_$chk_io(ppn1,
ppn2: integer32): integer; options(val_param)`.  With `parity_err_regs`
the MMU_BESR byte's record and the registers MMU_BESR, MMU_PEARH and
MMU_PEARL, and PARITY_$INFO's and the log entry's forms that hold it;
with `parity_dma_pages` the channel table, PARITY_$DMA_TABLE in place of
PARITY_$DURING_DMA, and the headings of PARITY_$CHK_IO (the channel)
and PARITY_$SET_STATE, which the SCSI_ module calls too.  The modules
whose code calls the two-page PARITY_$CHK_IO under every configuration
(ring/ring.pas, win/win.pas) declare that heading themselves under
`parity_dma_pages`.

Changes to shared insert files:
- `mmu/mmu.ins.pas`: the memory error word (a 16-bit packed record of
  three variants, SAU1 and SAU2 layouts and the whole word), the error
  longword, the MMU page's registers as PARITY reads them, the PFT entry
  (a packed record, ASID and protection fields), the IODEFS variables
  `mmu` and `pft`, and the headings of the hand-written MMU_$REMOVE,
  MMU_$INSTALL (the conformance unit `ast_page_zero.pas`'s) and
  MMU_$PTOV.
- `cache/cache.ins.pas` (new): CACHE_$CLEAR, a procedure.
- `ast/ast.ins.pas`: AST_$REMOVE_CORRUPTED_PAGE, a boolean function of a
  linteger by value.
- `fim/fim.ins.pas`: fault_$parity and fault_$spurious_parity, Apollo's
  fault.ins.pas names and values.

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### What the image does

At points that are easy to misread (all in PARITY_$CHK; `chk.pas`'s
header lists them):
- The second path's status copy is the error longword's **low** word.
- The first path's PARITY_$DURING_DMA comes from bit 3 of the status
  copy taken before the register is cleared.
- The first path's scan tests bits 2 and 1 of the error **word**.
- After a first-path hit the word written back is `par_buff[word_index]`,
  the word's own index.
- The second path's lanes are bits 11..8 of the error word (its high
  byte), and the "even byte" test is of those lanes.
- The second path reads the lanes from the register before it re-reads
  the failing word, both after the register is cleared; what the order
  changes depends on whether the re-read latches the error again.
- `byte_offset` is cleared once, after the install; the mapping is
  restored with `if va <> 0` with the install first; the PFT index is a
  word; PARITY_$CHK_IO returns a word (the callers read D0's low word;
  its high half is ppn2's, left from the entry load).

Which machines take which path: the test is bit 0 of the MMU
status byte.  The names SAU1/SAU2 for the two paths are not machines:
SAU2 is the DN300/DN320/DN330 family.  The first
path's layout (the word at 0xFFB406, the failing PPN in bits 15..4, two
byte-lane flags and a DMA flag in bits 3..1) is the DN300/DN320 memory
status register (Domain Engineering Handbook, DN3xx chapter, 7-22; MAME's
`APOLLO_DN300_MCSR_SR_*` give the same bit order as the image: 3 DMA, 2
left, 1 right, 0 traps enabled; the handbook's table lists them
the other way round).  The second path's (the longword at 0xFFB404,
failing A(21:2) in bits 31..12, byte-parity flags in bits 11..8 with 0 =
error) is the DN330 memory control/status register (7-23), and the
DN330's MMU status bit 0 is 0 on its 68020 board (7-25), the second
path.  So both paths run on SAU2 machines: the first path on a
DN300/DN320 (if its status bit 0 reads set, which the handbook does not
say), the second on a DN330.

chk_in_progress (set by PARITY_$CHK) is cleared by the caller, the
hand-written FIM_$PARITY_TRAP, after the call, not by PARITY_$CHK.

With `parity_err_regs` (PARITY_$CHK, `chk.pas`'s first body):
- The scan reads PAR_BUFF's first 256 words, stepping 2 bytes, while
  the address it records for word i and lane l is i * 4 + l, a byte of
  the i-th longword.
- err_data is the word read, or for lanes 0 and 1 that word shifted
  right by 16 after sign extension.
- PARITY_$INFO's err_data is at +0x14, beyond the map's 0x14 bytes of
  PARITY_$INFO (the first word of MISS_STATUS).
- After the error and again after the lane is found, bit 4 of MMU_CCR
  is set around a CACHE_$CLEAR and the system crashes unless MMU_BESR
  then shows every lane good.
- The scratch mapping is removed by address with MMU_$REMOVE; the
  frame keeps its own mapping (the page tables map a frame at several
  addresses, where the SAU2's PFT has one).

### TODO(pascal)

- `chk.pas`: 16 frame bytes below the result local (stand-ins
  `unused_38`, `unused_3a`); with `parity_err_regs` 20 bytes (stand-ins
  `unused_1c` .. `unused_22`, `unused_3c`).
- `chk_io.pas`: 4 frame bytes (stand-in `unused_8`).
- `set_state.pas`: 4 frame bytes (stand-in `unused_c`).
- `parity.pas`: the MMU headings without `pft_mmu` (MMU_$REMOVE's
  address form) belong in `mmu/mmu.ins.pas`.
