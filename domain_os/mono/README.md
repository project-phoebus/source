# The MONO module in Domain Pascal

The driver of a monochrome display board on the AT bus, in two forms:
1024 by 800 (display type 11, `smd_$bw5_1024x800` in Apollo's
smdu.ins.pas) and 1280 by 1024 (type 9, `smd_$bw4_1280x1024`,
"DN3000M"), each with its routine vector.  The routines are the ones the
display driver (SMD_, `display_devices`) calls for the board, with its
four units' descriptors and the vectors.  The SAU7 and SAU8 have the
driver (the part `mono_driver`, `../base/config.ins.pas`); translated
from the SAU8 image.  It has COLOR4's shape (`../color4/`), several of
its .TEXT and wired routines the same code as COLOR5's (`../color5/`),
with its own display memory sizing (line_bits * word_74 bits), its own
cursor (drawn by a nested routine and remembered in the unit's state)
and lights.  The other SAUs' maps have no MONO segment, and both module
files compile to nothing there.

## Layout

| map piece | section | size | file |
|-----------|---------|------|------|
| MONO code | OS_INIT_PROC | 0x1DC | `mono.pas`: MONO_$IOINIT, MONO_$INSTALL_DISP_MEM, `[section(os_init_proc, os_init_data)]` |
| MONO code | .TEXT | 0x32C | `mono.pas`: MONO_$CLEAR_SCREEN .. MONO_$DISPLAY_LOGO, no attribute |
| MONO code | MONO_WIRED_PROC | 0x664 | `mono.pas`: MONO_$COPY_FONT_MD_HDM .. MONO_$END_WIRED_PROC, `[section(mono_wired_proc, wired_data)]` |
| MONO data | WIRED_DATA | 0x20 | `mono.pas`: MONO_$LIGHTS's columns, a static |
| MONO data | .DATA | 0x8 | `mono.pas`: the module's variables, MONO_$REL_DISP's position and MONO_$DEBUG |
| MONO_DCTE | WIRED_DATA | 0x100 | `mono_dcte.pas`: MONO_$UNIT_BIG1, MONO_$UNIT_SMALL1, MONO_$UNIT_SMALL1A, MONO_$UNIT_SMALL2 |
| MONO_$WIRED_DATA | its own (overlay) | 0x2D8 | `mono_dcte.pas`: `var (mono_$wired_data)`, the areas, the two vectors, the units' state and requests |
| MONO_END_DATA | its own (overlay) | 0x4 | `mono_dcte.pas`: `var (mono_end_data)`, the end of the data area |

`mono.pas` is `module mono;`; `mono_dcte.pas` is `module mono_dcte, ,
wired_data;`, a module of data only, which `tools/pascal_check.sh` finds
by its module heading.  Both are under `mono_driver` and compile to
empty objects elsewhere.

MONO_$END_WIRED_PROC is compiled: an empty procedure, the last of the
wired section, whose address ends the vectors' code area.

### The SAU7

The SAU7's MONO and MONO_DCTE segments have the SAU8's sizes, code and
data at other addresses: the instructions are the same but for their
address operands, the data blocks the same bytes but for their address
cells.  The SAU7 build is the SAU8's source; every fragment has its
`sau7` address row.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MONO_$IOINIT | `ioinit.pas` |
| MONO_$INSTALL_DISP_MEM | `install_disp_mem.pas` |
| MONO_$CLEAR_SCREEN | `clear_screen.pas` |
| MONO_$VIDEO_CTL | `video_ctl.pas` |
| MONO_$REL_DISP | `rel_disp.pas` |
| MONO_$MAP_DISPLAY_MEMORY | `map_display_memory.pas` |
| MONO_$UNMAP_DISPLAY_MEMORY | `unmap_display_memory.pas` |
| MONO_$ASSOC_CSRS | `assoc_csrs.pas` |
| MONO_$DISSOC | `dissoc.pas` |
| MONO_$DISPLAY_LOGO | `display_logo.pas` |
| MONO_$COPY_FONT_MD_HDM | `copy_font_md_hdm.pas` |
| MONO_$LOCK_DISPLAY | `lock_display.pas` |
| MONO_$XOR_CURSOR | `xor_cursor.pas` (with the nested xor_at) |
| MONO_$BLINK_CURSOR | `blink_cursor.pas` |
| MONO_$PUTC | `putc.pas` |
| MONO_$LIGHTS | `lights.pas` |
| MONO_$END_WIRED_PROC | `end_wired_proc.pas` |

## Insert files

- `mono.ins.pas` (new): the constants, the board's registers, the
  vector, state and descriptor records, MONO's view of the display
  driver's records, SMD_$CURSOR_TABLE, and the headings of the
  seventeen routines.  Only MONO's own modules include it.

## Open items

- The board's register bits and bytes are named by position (flag_9 ..
  flag_15, reg_400 .. reg_406) and the command values are bare: their
  meanings are the board's.
