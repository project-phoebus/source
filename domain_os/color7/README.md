# The COLOR7 module in Domain Pascal

The driver of the coyote color display board (display type 14,
`smd_$color7_display` in Apollo's smdu.ins.pas): the routines the
display driver (SMD_, `display_devices`) calls for it through its
routine vector, its one unit's descriptor and the vector itself.  The
board is reached at fixed addresses: its registers from the address in
COLOR7_STATIC, its display memory at `color7_$memory_va`.  The drawing
engine's registers are set for the full screen before each drawing; the
color map's ports, the cursor's included, are written a register at a
time (color7_write_reg).  Only the SAU7 has the driver (the part
`color7_driver`, `../base/config.ins.pas`); on the other SAUs the map's
4-byte COLOR7 code segment in the COLOR7_WIRED_PROC section holds only
`COLOR7_$WORTHLESS`, an empty procedure, and the DCTE module compiles
to nothing.

## Layout

| map piece          | section           | size  | file |
|--------------------|-------------------|-------|------|
| COLOR7 code        | OS_INIT_PROC      | 0xD00 | `color7.pas`: COLOR7_$IOINIT, COLOR7_$COLD_INIT, `[section(os_init_proc, os_init_data)]` |
| COLOR7 code        | .TEXT             | 0x318 | `color7.pas`: COLOR7_$VIDEO_CTL .. COLOR7_$LOAD_CRSR, no attribute |
| COLOR7 code        | COLOR7_WIRED_PROC | 0x734 | `color7.pas`: COLOR7_$START_WIRED_PROC .. COLOR7_$END_WIRED_PROC with two module-local routines, `[section(color7_wired_proc, wired_data)]` |
| COLOR7 data        | WIRED_DATA        | 0x4   | none: 4 zero bytes (`color7.pas`'s TODO) |
| COLOR7 data        | OS_INIT_DATA      | 0x2E0 | `color7.pas`: COLOR7_$IOINIT's statics, the timing port's four tables |
| COLOR7 data        | .DATA             | 0x4   | none: 4 zero bytes (`color7.pas`'s TODO) |
| COLOR7_DCTE        | WIRED_DATA        | 0x40  | `color7_dcte.pas`: COLOR7_$DCTE |
| COLOR7_$WIRED_DATA | its own (overlay) | 0xA8  | `color7_dcte.pas`: `var (color7_$wired_data)`, the areas, the vector and the unit's state |
| COLOR7_STATIC      | its own (overlay) | 0x10  | `color7.pas`: `var (color7_static)`, the driver's state |
| COLOR7_END_DATA    | its own (overlay) | 0x4   | `color7_dcte.pas`: `var (color7_end_data)`, the end of the data area |
| COLOR7 code        | COLOR7_WIRED_PROC | 0x4   | `color7.pas` without the driver: COLOR7_$WORTHLESS, `[section(color7_wired_proc, color7_$wired_data)]` |

`color7.pas` is `module color7;`; `color7_dcte.pas` is `module
color7_dcte, , wired_data;`, a module of data only (`../color6/`'s
form), which `tools/pascal_check.sh` finds by its module heading.  The
routines take the descriptor's address first.  The records in
`color7.ins.pas` are what COLOR7 itself reads and writes of the display
driver's records, with stand-ins between.

The module-local routines are `internal` and have `forward; internal;`
headings in `color7.pas`, since the OS_INIT_PROC and .TEXT routines call
them before their bodies.  The board's register blocks past the drawing
engine's (the ports, the control register, the engine's status, the
identification ROM) are reached through pointers formed from the
board's address plus their offsets.

## Routines and their fragments

| routine                    | fragment |
|----------------------------|----------|
| COLOR7_$IOINIT             | `ioinit.pas` |
| COLOR7_$COLD_INIT          | `cold_init.pas` |
| COLOR7_$VIDEO_CTL          | `video_ctl.pas` |
| COLOR7_$CLEAR_SCREEN       | `clear_screen.pas` |
| COLOR7_$MAP_DISPLAY_MEMORY | `map_display_memory.pas` |
| COLOR7_$ASSOC_CSRS         | `assoc_csrs.pas` |
| COLOR7_$DISSOC             | `dissoc.pas` |
| COLOR7_$PUTC               | `putc.pas` |
| COLOR7_$DISPLAY_LOGO       | `display_logo.pas` |
| COLOR7_$SHUTDOWN           | `shutdown.pas` |
| COLOR7_$LOAD_CRSR          | `load_crsr.pas` |
| COLOR7_$START_WIRED_PROC   | `start_wired_proc.pas` |
| color7_wait_idle           | `wait_idle.pas` |
| color7_write_reg           | `write_reg.pas` |
| COLOR7_$COPY_FONT_MD_HDM   | `copy_font_md_hdm.pas` |
| COLOR7_$LOCK_DISPLAY       | `lock_display.pas` |
| COLOR7_$XOR_CURSOR         | `xor_cursor.pas` |
| COLOR7_$BLINK_CURSOR       | `blink_cursor.pas` |
| COLOR7_$BUSY_WAIT          | `busy_wait.pas` |
| COLOR7_$LITES              | `lites.pas` |
| COLOR7_$END_WIRED_PROC     | `end_wired_proc.pas` |
| COLOR7_$WORTHLESS          | `worthless.pas` |

## Insert files

- `color7.ins.pas`: the constants, the board's register blocks
  (`[device]` records, the control register's bits a set, the engine's
  status a packed record), the descriptor, the unit's state, the vector,
  the driver's state, and every global's heading.
- Elsewhere: `../mmu/mmu.ins.pas` declares ROADRUNNER.  io/dctes.pas's
  DEV_DCTES lists COLOR7_$DCTE on the SAU7 (not yet in that file's sau7
  form).

## Open items

- TODO(pascal): the 4-byte WIRED_DATA and .DATA blocks and the A5
  loads into them (`color7.pas`'s TODO).
- TODO(pascal): the frames larger than the declared locals
  (`color7.pas`'s TODO).
- The register names past their offsets (the drawing engine's
  registers, the ports, the control register's bits, the status's two
  fields) are the board's, not known from Apollo's inserts.
