# The COLOR5 module in Domain Pascal

The driver of a color display board on the AT bus (display type 10,
`smd_$color5` in Apollo's smdu.ins.pas): the routines the display driver
(SMD_, `display_devices`) calls for it through its routine vector, its
two units' descriptors and the vector itself.  The SAU7 and SAU8 have
the driver (the part `color5_driver`, `../base/config.ins.pas`);
translated from the SAU8 image.  It has COLOR4's shape (`../color4/`),
most of its .TEXT routines the same code, with its own registers, its
own cursor (it keeps what it saved in the unit's state) and lights.  The
other SAUs configure it out: there the map's COLOR5 code segment (4
bytes) in the COLOR5_WIRED_PROC section holds only `COLOR5_$WORTHLESS`,
an empty procedure, and the module-end filler.

## Layout

| map piece | section | size | file |
|-----------|---------|------|------|
| COLOR5 code | OS_INIT_PROC | 0x2B0 | `color5.pas`: COLOR5_$IOINIT, COLOR5_$INSTALL_DISP_MEM, `[section(os_init_proc, os_init_data)]` |
| COLOR5 code | .TEXT | 0x340 | `color5.pas`: COLOR5_$CLEAR_SCREEN .. COLOR5_$DISPLAY_LOGO, no attribute |
| COLOR5 code | COLOR5_WIRED_PROC | 0x6EC | `color5.pas`: COLOR5_$COPY_FONT_MD_HDM .. COLOR5_$LIGHTS, `[section(color5_wired_proc, wired_data)]` |
| COLOR5 data | WIRED_DATA | 0x20 | `color5.pas`: COLOR5_$LIGHTS's columns, a static |
| COLOR5 data | .DATA | 0x4 | `color5.pas`: the module's variable, COLOR5_$REL_DISP's position |
| COLOR5_DCTE | WIRED_DATA | 0x80 | `color5_dcte.pas`: COLOR5_$DCTE1, COLOR5_$DCTE2 |
| COLOR5_$WIRED_DATA | its own (overlay) | 0x184 | `color5_dcte.pas`: `var (color5_$wired_data)`, the areas, the vector, the units' state and requests |
| COLOR5_END_DATA | its own (overlay) | 0x4 | `color5_dcte.pas`: `var (color5_end_data)`, the end of the data area |

`color5.pas` is `module color5;`; `color5_dcte.pas` is `module
color5_dcte, , wired_data;`, a module of data only, which
`tools/pascal_check.sh` finds by its module heading.  Without the driver
`color5.pas` is the empty procedure `[section(color5_wired_proc,
color5_$wired_data)]` and `color5_dcte.pas` compiles to nothing.

COLOR5_$START_WIRED_PROC (at COLOR5_$COPY_FONT_MD_HDM) and
COLOR5_$END_WIRED_PROC (the first symbol of the section after
COLOR5_WIRED_PROC) are layout marks, not objects of these modules; the
vector's code area ends at COLOR5_$END_WIRED_PROC.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR5_$IOINIT | `ioinit.pas` |
| COLOR5_$INSTALL_DISP_MEM | `install_disp_mem.pas` |
| COLOR5_$CLEAR_SCREEN | `clear_screen.pas` |
| COLOR5_$VIDEO_CTL | `video_ctl.pas` |
| COLOR5_$REL_DISP | `rel_disp.pas` |
| COLOR5_$MAP_DISPLAY_MEMORY | `map_display_memory.pas` |
| COLOR5_$UNMAP_DISPLAY_MEMORY | `unmap_display_memory.pas` |
| COLOR5_$ASSOC_CSRS | `assoc_csrs.pas` |
| COLOR5_$DISSOC | `dissoc.pas` |
| COLOR5_$DISPLAY_LOGO | `display_logo.pas` |
| COLOR5_$COPY_FONT_MD_HDM | `copy_font_md_hdm.pas` |
| COLOR5_$LOCK_DISPLAY | `lock_display.pas` |
| COLOR5_$XOR_CURSOR | `xor_cursor.pas` |
| COLOR5_$BLINK_CURSOR | `blink_cursor.pas` |
| COLOR5_$PUTC | `putc.pas` |
| COLOR5_$LIGHTS | `lights.pas` |
| COLOR5_$WORTHLESS | `worthless.pas` |

## Insert files

- `color5.ins.pas`: the constants, the board's registers, the vector,
  state and descriptor records, COLOR5's view of the display driver's
  records, SMD_$CURSOR_TABLE, COLOR5_$END_WIRED_PROC, and the headings of
  the sixteen routines.

## Open items

- The board's register bits and bytes are named by position (flag_9 ..
  flag_15, reg_400 .. reg_407) and the values COLOR5_$IOINIT writes to
  them are bare: their meanings are the board's.
