# The AS subsystem in Domain Pascal

The address-space layout queries.

## Layout

One module, `as.pas`, `module as;` (both code segments are named AS):

| section      | code size | routines | attribute |
|--------------|-----------|----------|-----------|
| OS_INIT_PROC | 0x5C   | AS_$INIT (0x5A of code, then the module-end filler) | `[section(os_init_proc, os_init_data)]` |
| .TEXT        | 0xE8   | AS_$GET_INFO, AS_$GET_ADDR (its jump table inside) | none |

Data: none of the module's own.  AS_$INFO (0x5C bytes) and AS_$INFO_SIZE
are map symbols of the map's AS_ASM data segment (0x64 bytes), a
hand-written block in WIRED_DATA, so they are extern variables in
`as.ins.pas`; the block is transcribed in `m68k/as_asm.s`.  No routine
loads A5.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| AS_$INIT | `init.pas` |
| AS_$GET_INFO | `get_info.pas` (a `for` over the record's bytes) |
| AS_$GET_ADDR | `get_addr.pas` (a `case` with a jump table, arms 1 and 3 sharing their tail) |
| (data) | none: the hand-written AS_ASM block (`m68k/as_asm.s`), extern here |

`as.ins.pas`: the address range `as_$addr_range_t`; AS_$INFO's type
`as_$info_t` (the map's nine interior symbols as fields, a byte variant
for AS_$GET_INFO's copy); the extern AS_$INFO and AS_$INFO_SIZE; the
three headings (AS_$INIT none; the two SVC entries the default
convention, `out`/`in` as the image reads and writes).

Shared insert files:
- `mmu/mmu.ins.pas`: the extern M68020 (a boolean byte of the
  hand-written MMU's data).
- `mst/mst.ins.pas`: the six MST_ segment words AS_$GET_ADDR reads
  (pinteger, extern); with `large_address_space` (the SAU7, SAU9)
  constants, and private B is 128 segments (AS_$GET_ADDR's
  `as_private_b_size`).

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Names and layout

- The map's AS_$STACK_OFFSET is at +0x40 of AS_$INFO; AS_$INIT adds to
  the longword at +0x44, which the map does not name.  Here +0x40 is
  `stack_offset` and +0x44 `l_44`.
- The map's interior symbols make several longwords parts of larger
  objects (AS_$CR_REC 0x18 bytes, AS_$STACK_LOW 8, AS_$STACK_OFFSET and
  AS_$INIT_STACK_FILE_SIZE 12, AS_$GLOBAL_A 16); nothing compiled reads
  them as such, so the fields stay longwords.

### TODO(pascal)

- `init.pas`: 8 frame bytes (stand-in `unused_8`).
- `get_info.pas`: 10 frame bytes (stand-ins `unused_8`, `unused_c`).
