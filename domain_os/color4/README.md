# The COLOR4 module in Domain Pascal

The driver of a color display board on the AT bus (display type 8,
`smd_$color4` in Apollo's smdu.ins.pas, "DN3000C"): the routines the
display driver (SMD_, `display_devices`) calls for it through its
routine vector, its two units' descriptors and the vector itself.  The
SAU7 and SAU8 have the driver (the part `color4_driver`,
`../base/config.ins.pas`); translated from the SAU8 image.  The other
SAUs configure it out: there the map's COLOR4 code segment (4 bytes) in
the COLOR4_WIRED_PROC section holds only `COLOR4_$WORTHLESS`, an empty
procedure.

## Layout

| map piece | section | size | file |
|-----------|---------|------|------|
| COLOR4 code | OS_INIT_PROC | 0x238 | `color4.pas`: COLOR4_$IOINIT, COLOR4_$INSTALL_DISP_MEM, `[section(os_init_proc, os_init_data)]` |
| COLOR4 code | .TEXT | 0x33C | `color4.pas`: COLOR4_$CLEAR_SCREEN .. COLOR4_$SET_COLOR_TABLE, no attribute |
| COLOR4 code | COLOR4_WIRED_PROC | 0x650 | `color4.pas`: COLOR4_$COPY_FONT_MD_HDM .. COLOR4_$LITES, `[section(color4_wired_proc, wired_data)]` |
| COLOR4_ASM | COLOR4_WIRED_PROC | 0xA8 | `m68k/color4_asm.s`: hand assembly |
| COLOR4 data | WIRED_DATA | 0x28 | `color4.pas`: COLOR4_$LITES's tables, statics |
| COLOR4 data | OS_INIT_DATA | 0x10 | `color4.pas`: COLOR4_$IOINIT's ramp, a static |
| COLOR4 data | .DATA | 0x8 | `color4.pas`: the module's variables, COLOR4_$REL_DISP's position and COLOR4_$DEBUG |
| COLOR4_DCTE | WIRED_DATA | 0x80 | `color4_dcte.pas`: COLOR4_$UNIT_2, COLOR4_$UNIT_1 |
| COLOR4_$WIRED_DATA | its own (overlay) | 0x174 | `color4_dcte.pas`: `var (color4_$wired_data)`, the areas, the vector, the units' state and requests |
| COLOR4_END_DATA | its own (overlay) | 0x4 | `color4_dcte.pas`: `var (color4_end_data)`, the end of the data area |

`color4.pas` is `module color4;`; `color4_dcte.pas` is `module
color4_dcte, , wired_data;`, a module of data only (`../io/dctes.pas`'s
form), which `tools/pascal_check.sh` finds by its module heading.
Without the driver `color4.pas` is the empty procedure
`[section(color4_wired_proc, color4_$wired_data)]` and `color4_dcte.pas`
compiles to nothing.

COLOR4_ASM is in the maps of the SAUs with the device-based display
driver only (`display_devices`: the SAU7, SAU8, SAU9), byte for byte the
same on each; `m68k/color4_asm.s` assembles to nothing on the others.

The routines take the descriptor's address first.  The records in
`color4.ins.pas` are what COLOR4 itself reads and writes of the display
driver's interface (its display record, its blink state, its cursor
patterns), with stand-ins between.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR4_$IOINIT | `ioinit.pas` |
| COLOR4_$INSTALL_DISP_MEM | `install_disp_mem.pas` |
| COLOR4_$CLEAR_SCREEN | `clear_screen.pas` |
| COLOR4_$VIDEO_CTL | `video_ctl.pas` |
| COLOR4_$REL_DISP | `rel_disp.pas` |
| COLOR4_$MAP_DISPLAY_MEMORY | `map_display_memory.pas` |
| COLOR4_$UNMAP_DISPLAY_MEMORY | `unmap_display_memory.pas` |
| COLOR4_$ASSOC_CSRS | `assoc_csrs.pas` |
| COLOR4_$DISSOC | `dissoc.pas` |
| COLOR4_$DISPLAY_LOGO | `display_logo.pas` |
| COLOR4_$SET_COLOR_TABLE | `set_color_table.pas` |
| COLOR4_$COPY_FONT_MD_HDM | `copy_font_md_hdm.pas` |
| COLOR4_$LOCK_DISPLAY | `lock_display.pas` |
| COLOR4_$XOR_CURSOR | `xor_cursor.pas` |
| COLOR4_$BLINK_CURSOR | `blink_cursor.pas` |
| COLOR4_$PUTC | `putc.pas` |
| COLOR4_$LITES | `lites.pas` |
| COLOR4_$WORTHLESS | `worthless.pas` |
| COLOR4_$LOAD_LUT | none: hand assembly (COLOR4_ASM, `m68k/color4_asm.s`) |
| COLOR4_$END_WIRED_PROC | none: hand assembly (a marker word in `m68k/color4_asm.s`) |

## Insert files

- `color4.ins.pas`: the constants, the board's registers, the vector,
  state and descriptor records, COLOR4's view of the display driver's
  records, SMD_$CURSOR_TABLE, and the headings of the seventeen routines
  and of COLOR4_ASM's.
- `../dtty/dtty.ins.pas` (extended): RELOAD_FONT.

## Open items

- The board's register bits are named by position (flag_9 .. flag_15,
  reg_400, reg_404, reg_406) and the command values written to reg_406
  are bare: their meanings are the board's.
- COLOR4_$COPY_FONT_MD_HDM copies from the font pointer's address plus 4,
  the 39 lines of 14 words that follow DTTY_$STD_FONT_P in DTTY_ASM's
  data.
