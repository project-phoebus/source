# The UID subsystem in Domain Pascal

The unique identifier generator.

## Layout

The SAU2 map has four UID code segments and one data segment; three of
them are the one compiled module of this subsystem:

| segment | section | routines | Pascal |
|---------|---------|----------|--------|
| UID_ code, 0xE4 bytes | WIRED_PROC | UID_$GEN | `uid.pas`, no attribute |
| UID_ code, 0x20 bytes | OS_INIT_PROC | UID_$INIT | `uid.pas`, `[section(os_init_proc, os_init_data)]` |
| UID_ data, 0xC bytes | WIRED_DATA | (data, no symbol) | `uid.pas`'s two variables |
| UID_$HASH code, 0x1C bytes | WIRED_PROC | UID_$HASH | none: **hand-written** |
| UID_LIST, 0x210 bytes | WIRED_PROC | (the well-known UIDs, UID_$NIL ..) | none: data only, hand assembly (`m68k/uid_list.s`) |

`uid.pas` is `module uid_, wired_proc, wired_data;`.  Its block's
objects, the module's own (no map symbol inside):

| offset | variable | type |
|--------|----------|------|
| +0x00 | `uid_$generator_state` | `uid_$gen_state_t` (8 bytes: a uid_$t; the high longword with a packed low longword; a byte variant) |
| +0x08 | `uid_$generator_lock` | integer32 (ML_$SPIN_LOCK's `var lock`) |

UID_$HASH is hand assembly: no frame, both arguments read off the stack,
a word divide whose remainder is swapped into D0's low word, and no
filler before UID_LIST.  It gets no Pascal; its heading for Pascal
callers is in `uid.ins.pas`, from its 16 callers (two addresses, the
word of D0 read).  It is transcribed in `uid/m68k/hash.s`.  UID_LIST is
a table of 8-byte constants in a code section, 0x210 bytes with no code,
no filler, 66 UIDs under 80 map names (13 cells have two or three); it
is `uid/m68k/uid_list.s`, every map name a label (a Pascal variable has
one name, and the layout keys a dpc block only by a
`D` segment; the file's header has the dpc probe).  `base/base.ins.pas`
and the other insert files declare the names they use extern.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| UID_$GEN | `gen.pas` (two loops; no nested or module-local routine) |
| UID_$INIT | `init.pas` |
| UID_$HASH | none: hand assembly (`m68k/hash.s`) |
| (data) | the generator's state and lock are `uid.pas`'s variables; NODE_$ME and the well-known UIDs belong to NET_ASM and UID_LIST |

`uid.ins.pas`: `uid_$byte_t`, the packed low longword `uid_$gen_low_t`
(counter nibble, 8 bits, the 20-bit node field), the state
`uid_$gen_state_t`, the headings of UID_$HASH (hand-written, the
default convention, an integer function), UID_$GEN (`out uid_ret`) and
UID_$INIT.

Changes to shared insert files:
- `time/time.ins.pas`: TIME_$CLOCKH (extern time_$clockh_t) and the
  hand-written TIME_$ABS_CLOCK (`out clock: time_$clock_t`).
- `node/node.ins.pas` (new): NODE_$ME, extern linteger (merged unmasked
  into a packed field).

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Facts of the layout

- UID_$GENERATOR_LOCK is integer32: the block is 0xC bytes, and
  ML_$SPIN_LOCK's lock is a longword (`ml/ml.ins.pas`).
- UID_$GEN's counter is the top nibble of the low longword (bits
  31..28), compared, then bumped as such (16 added to its byte).
- UID_$INIT's in-place clear, then merge, is the packed field's store.

### TODO(pascal)

None.

`uid.ins.pas` (appended at the end): DISKLESS_$UID (extern uid_$t), moved from file/file.ins.pas's TODO(merge);
FILE_$LOCATEI's module, file/file.pas, includes this file.
DISPLAY1_$UID stays in smd/smd_internal.ins.pas (os/os.pas declares its
own copy and includes this file; smd/smd.pas does not include it).
