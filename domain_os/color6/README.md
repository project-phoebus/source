# The COLOR6 module in Domain Pascal

The driver of the Matrox color display board on the AT bus (display
type 12, `smd_$color6_display` in Apollo's smdu.ins.pas, "matrox or
meerkatIII"): the routines the display driver (SMD_, `display_devices`)
calls for it through its routine vector, its three units' descriptors
and the vector itself.  The three units are pages of one board (their
controller numbers 5, 3 and 6), selected through the board's page
register before each access.  The board is little-endian: the driver
swaps the bytes of the words and longwords it exchanges with its
registers.  Only the SAU7 has the driver (the part `color6_driver`,
`../base/config.ins.pas`); the other SAUs' maps have no COLOR6 module,
only its three empty sections, and both module files compile to nothing
there.

## Layout

| map piece          | section           | size  | file |
|--------------------|-------------------|-------|------|
| COLOR6 code        | OS_INIT_PROC      | 0x2A8 | `color6.pas`: COLOR6_$IOINIT (with its nested color6_probe), COLOR6_$INSTALL_DISP, `[section(os_init_proc, os_init_data)]` |
| COLOR6 code        | .TEXT             | 0x618 | `color6.pas`: color6_swap32, COLOR6_$CLEAR_SCREEN .. COLOR6_$DISPLAY_LOGO, color6_send_cursor and color6_release, no attribute |
| COLOR6 code        | COLOR6_WIRED_PROC | 0x4E0 | `color6.pas`: COLOR6_$START_WIRED_PROC .. COLOR6_$END_WIRED_PROC with six module-local routines, `[section(color6_wired_proc, wired_data)]` |
| COLOR6 data        | WIRED_DATA        | 0x18  | `color6.pas`: the statics of color6_fifo_count (a spin lock), color6_drain_fifo (two delays) and COLOR6_$LOCK_DISPLAY (a spin lock) |
| COLOR6 data        | OS_INIT_DATA      | 0x8   | `color6.pas`: COLOR6_$IOINIT's statics (the board's page, two flags) and COLOR6_$INSTALL_DISP's |
| COLOR6 data        | .DATA             | 0x1F0 | `color6.pas`: the module's variables, COLOR6_$ASID_MAP first |
| COLOR6_DCTE        | WIRED_DATA        | 0xC0  | `color6_dcte.pas`: COLOR6_$UNIT_1, COLOR6_$UNIT_2, COLOR6_$UNIT_3 |
| COLOR6_$WIRED_DATA | its own (overlay) | 0x1A0 | `color6_dcte.pas`: `var (color6_$wired_data)`, the areas, the vector, the units' state and the board's five requests |
| COLOR6_END_DATA    | its own (overlay) | 0x4   | `color6_dcte.pas`: `var (color6_end_data)`, the end of the data area |

`color6.pas` is `module color6;`; `color6_dcte.pas` is `module
color6_dcte, , wired_data;`, a module of data only (`../color4/`'s form),
which `tools/pascal_check.sh` finds by its module heading.  The routines
take the descriptor's address first.  The records in `color6.ins.pas` are
what COLOR6 itself reads and writes of the display driver's records,
with stand-ins between.

The module-local routines are `internal`: they inherit A5, so the wired
ones' statics are reached through the block their callers load.  The
wired routines that the OS_INIT_PROC and .TEXT routines call before
their bodies have `forward; internal;` headings in `color6.pas`.
color6_probe reads COLOR6_$IOINIT's statics and no frame of its parent:
it is nested in it and reads no static link.

## Routines and their fragments

| routine                  | fragment |
|--------------------------|----------|
| COLOR6_$IOINIT           | `ioinit.pas` (with the nested color6_probe) |
| COLOR6_$INSTALL_DISP     | `install_disp.pas` |
| color6_swap32            | `swap32.pas` |
| COLOR6_$CLEAR_SCREEN     | `clear_screen.pas` |
| COLOR6_$VIDEO_CTL        | `video_ctl.pas` |
| color6_send_cursor       | `send_cursor.pas` |
| COLOR6_$REL_DISP         | `rel_disp.pas` |
| COLOR6_$MAP_DISP         | `map_disp.pas` |
| COLOR6_$UNMAP_DISP       | `unmap_disp.pas` |
| COLOR6_$SET_CRS_PAT      | `set_crs_pat.pas` |
| color6_release           | `release.pas` |
| COLOR6_$ASSOC            | `assoc.pas` |
| COLOR6_$DISSOC           | `dissoc.pas` |
| COLOR6_$DEVICE_INFO      | `device_info.pas` |
| COLOR6_$DISPLAY_LOGO     | `display_logo.pas` |
| COLOR6_$START_WIRED_PROC | `start_wired_proc.pas` |
| color6_swap16            | `swap16.pas` |
| color6_get_page          | `get_page.pas` |
| color6_set_page          | `set_page.pas` |
| color6_wait_ready        | `wait_ready.pas` |
| color6_fifo_count        | `fifo_count.pas` |
| color6_drain_fifo        | `drain_fifo.pas` |
| COLOR6_$BUSY_WAIT        | `busy_wait.pas` |
| color6_wait_idle         | `wait_idle.pas` |
| COLOR6_$XOR_CURSOR       | `xor_cursor.pas` |
| COLOR6_$BLINK_CURSOR     | `blink_cursor.pas` |
| COLOR6_$PUTC             | `putc.pas` |
| COLOR6_$LOCK_DISPLAY     | `lock_display.pas` |
| COLOR6_$END_WIRED_PROC   | `end_wired_proc.pas` |

## Insert files

- `color6.ins.pas`: the constants, the board's registers (a `[device]`
  record of its four pages, the control word a set of its bits), the
  descriptor, the unit's state, the vector, the address-space mapping's
  element, the device information, and every global's heading.
- Elsewhere: none changed.  io/dctes.pas's DEV_DCTES lists the three
  descriptors on the SAU7 (not yet in that file's sau7 form).

## Open items

- TODO(pascal): the frames larger than dpc's layout of the declared
  locals (`color6.pas`'s TODO).
- The register names past their offsets (the control word's bits, the
  two count-select words, the board's identification word) are the
  board's, not known from Apollo's inserts.
