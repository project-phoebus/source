# The TAPE subsystem in Domain Pascal

Tape boot, configured out of the SR10.2 kernel.

## Layout

One module, `tape.pas`, `module tape_boot;` (the map segment's name is
TAPE_BOOT; the directory stays tape/):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| OS_INIT_PROC | 0x10 bytes | TAPE_$BOOT | `[section(os_init_proc, os_init_data)]` |

Data: the map's TAPE_BOOT data segment, 4 bytes in OS_INIT_DATA, zero,
no symbol inside, never addressed by TAPE_$BOOT (no A5).  The only
operand on it in the image is XPD_$INIT's A5, the end of XPD's own
4-byte block.  The module declares nothing for it (TODO in `tape.pas`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| TAPE_$BOOT | `boot.pas`: without `tape_boot` a function that clears `entry_point` and returns false; with it (the SAU5's) the boot from the cartridge tape, with ten nested routines (tape_$print .. tape_$load_file) |

With `tape_boot`, `tape.ins.pas` adds the tape's block and record
formats, the two CT_ statuses and the CT_$ACQUIRE, CT_$CONTROL,
CT_$READ and CT_$WAIT headings (TODO(merge): ct/ct.ins.pas), and
`tape.pas` includes the callees' insert files.  Open: dpc refuses the
three string constants passed by address (`boot.pas`'s TODO(pascal)),
so `tape.pas` does not compile for the SAU5 yet.  The SAU6..SAU9
TAPE_$BOOT bodies are the SAU5's but for the end's padding (the
catalog); their TAPE_BOOT code segments are 8 bytes shorter (0xA60).
The SAU9's segment, nested routines included, is the SAU5's source in
the 68020's code: no arm.

`tape.ins.pas` holds the heading, `function tape_$boot(out
entry_point: integer32; out status_ret: status_$t): boolean`, from the
body and its one caller PROC2_$INIT (two addresses, the result tested
as a boolean).

## Open items

The routine never writes the status: a caller cannot rely on
status_$ok from it.

TODO(pascal): `tape.pas`, the 4-byte OS_INIT_DATA block that nothing
addresses.
