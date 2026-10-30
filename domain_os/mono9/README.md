# The MONO9 subsystem in Domain Pascal

The DN2500's monochrome display: the routines the display driver calls
for it, its descriptor, and its hand-written register routines. Only the
SR10.2 SAU9 has it (the part `mono9_display`, `../base/config.ins.pas`);
the SAU2 and SAU5 builds compile both module files to empty objects.
Translated from the SAU9 image.

## Layout

The map has four pieces:

| map piece | section | size | file |
|-----------|---------|------|------|
| MONO9 code | WIRED_PROC | 0x88 | `mono9.pas`: MONO9_$LOCK_DISPLAY, MONO9_$BLINK_CURSOR, `[section(wired_proc, wired_data)]` |
| MONO9 code | OS_INIT_PROC | 0xA0 | `mono9.pas`: MONO9_$IOINIT, MONO9_$INSTALL_DISP, `[section(os_init_proc, os_init_data)]` |
| MONO9 code | .TEXT | 0x2DC | `mono9.pas`: MONO9_$COPY_FONT_MD_HDM .. MONO9_$DISPLAY_LOGO, no attribute |
| MONO9 data | WIRED_DATA | 4 | `mono9.pas`: MONO9_$LOCK_DISPLAY's spin lock, a static |
| MONO9_ASM | WIRED_DATA | 0x100 | `sau9/mono9_asm.s`: hand assembly |
| MONO9_DESC | DCTES | 0x40 | `mono9_desc.pas`: the DCTE MONO9_$UNIT |
| MONO9_$WIRED_DATA | its own (overlay) | 0xC8 | `mono9_desc.pas`: `var (mono9_$wired_data)`, the routine vector, the state, the configuration |

`mono9.pas` is `module mono9;` (its only data a routine's static);
`mono9_desc.pas` is `module mono9_desc, , dctes;`, a module of data only
(`../io/dctes.pas`'s form).  Which unit gave the overlay section its
bytes the map does not say; `mono9_desc.pas` holds them because the
descriptor is what points into them.  `tools/pascal_check.sh` finds
`mono9_desc.pas` by its module heading.

The routines are the SAU9's display driver's (SMD_, not translated):
it calls them through the vector in MONO9_$WIRED_DATA with the
descriptor's address first, and IO_$INIT calls MONO9_$IOINIT as the
descriptor's init routine.  The records in `mono9.ins.pas` are what
MONO9 itself reads and writes of that interface, with stand-ins
between.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MONO9_$LOCK_DISPLAY | `lock_display.pas` |
| MONO9_$BLINK_CURSOR | `blink_cursor.pas` |
| MONO9_$IOINIT | `ioinit.pas` |
| MONO9_$INSTALL_DISP | `install_disp.pas` |
| MONO9_$COPY_FONT_MD_HDM | `copy_font_md_hdm.pas` |
| MONO9_$CLEAR_SCREEN | `clear_screen.pas` |
| MONO9_$MAP_DISP | `map_disp.pas` |
| MONO9_$UNMAP_DISP | `unmap_disp.pas` |
| MONO9_$ASSOC | `assoc.pas` |
| MONO9_$DISSOC | `dissoc.pas` |
| MONO9_$DISPLAY_LOGO | `display_logo.pas` |
| DISP_QUERY | none: hand assembly (`sau9/mono9_asm.s`) |
| MONO9_$VIDEO_CTL | none: hand assembly (`sau9/mono9_asm.s`) |
| MONO9_$SET_COLOR_TABLE | none: hand assembly (`sau9/mono9_asm.s`) |
| MONO9_$XOR_CURSOR | none: hand assembly (`sau9/mono9_asm.s`) |

## Insert files

- `mono9.ins.pas` (new): the constants, the vector, state,
  configuration and descriptor records, the request, blink and cursor
  records, the logo line, and the headings of the eleven routines and
  of MONO9_ASM's four.
- `../smd/smd.ins.pas` (extended): SMD_$ADD_DEVICE.
- `../mst/mst.ins.pas` (extended): MST_$MAP_SPECIAL.
- `../mmu/mmu.ins.pas` (extended): MMU_$INSTALL_SPECIAL,
  MMU_$REMOVE_SPECIAL_SEG.

## Open items

- MONO9_$UNMAP_DISP replaces MST_$UNMAP's status with status_$ok.
- MONO9_$DISPLAY_LOGO tests the status a second time with nothing
  between that could change it.
- The vector's other cells, the configuration's words and the state's
  fields the driver alone uses have stand-in names; their meaning is
  the driver's, to be named when the SAU9's SMD_ is translated.
- The SAU9 layout must place MONO9_$WIRED_DATA as an initialized
  overlay section (dpc emits `.data.overlay.MONO9_$WIRED_DATA`, not a
  COMMON) and MONO9_DESC in the DCTES section.
