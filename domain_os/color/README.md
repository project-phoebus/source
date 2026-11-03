# The COLOR subsystem in Domain Pascal

The color graphics board's driver of the SAU4 and SAU5 machines (the
part `color_board`, `../base/config.ins.pas`), translated from the SAU5
and SAU4 images.

## Layout

One module, `color.pas`, `module color;` (the map segments' name); its
whole body is under `color_board`, so other SAUs compile it to nothing.

| section         | segment                           | routines                                                                            | attribute                                             |
|-----------------|-----------------------------------|-------------------------------------------------------------------------------------|-------------------------------------------------------|
| WIRED_PROC      | COLOR, 0x24 bytes                 | COLOR_$VIDEO_CTL                                                                    | `[section(wired_proc, wired_data)]`                   |
| OS_INIT_PROC    | COLOR, 0x70 bytes (SAU4 0x74)     | COLOR_$COLD_INIT                                                                    | `[section(os_init_proc, os_init_data)]`               |
| .TEXT (default) | COLOR, 0x440 bytes (SAU4 0x474)   | COLOR_$INT_INIT .. COLOR_$INQ_DONE_WAIT                                             | none                                                  |
| .DATA (default) | COLOR data, 0x8C bytes            | the wired pages, their count, the owner, the flag                                   | module variables                                      |
| WIRED_DATA      | COLOR_ASM, 0x9C bytes (SAU4 0x34) | COLOR_$VECTOR_INIT, COLOR_$IQ_DONE_EC; SAU5 also COLOR_$INT_DECODE, COLOR_$LOAD_MAP | hand assembly, `sau5/color_asm.s`, `sau4/color_asm.s` |

### The SAU4

The SAU4's COLOR is the SAU5's source with two parts:

- `color_board_iomap`: COLOR_$MAP and COLOR_$UNMAP write the wired
  pages' numbers into the I/O map's entries from 95 instead of the
  board's color map, the display commands are 16#E and 16#6, the
  interrupt vector 16#CE; its COLOR_ASM fills that vector itself and has
  no COLOR_$INT_DECODE or COLOR_$LOAD_MAP;
- `vm_regions`: COLOR_$ASSOC puts the board's user page in special
  segment 0 (MST_$MAP_SPECIAL, MMU_$INSTALL_SPECIAL) and keeps the
  owner's address space in the data block, whose special segment it
  removes when another process takes the board.

## Routines and their fragments

| routine                                                                   | fragment                                                    |
|---------------------------------------------------------------------------|-------------------------------------------------------------|
| COLOR_$VIDEO_CTL                                                          | `video_ctl.pas`                                             |
| COLOR_$COLD_INIT                                                          | `cold_init.pas`                                             |
| COLOR_$INT_INIT                                                           | `int_init.pas`                                              |
| COLOR_$ASSOC                                                              | `assoc.pas`                                                 |
| COLOR_$DISSOC                                                             | `dissoc.pas`                                                |
| COLOR_$SHUTDOWN                                                           | `shutdown.pas`                                              |
| COLOR_$MAP                                                                | `map.pas`                                                   |
| COLOR_$UNMAP                                                              | `unmap.pas`                                                 |
| COLOR_$LOAD_CRSR                                                          | `load_crsr.pas`                                             |
| COLOR_$INQ_DONE_WAIT                                                      | `inq_done_wait.pas`                                         |
| COLOR_$VECTOR_INIT, COLOR_$INT_DECODE, COLOR_$IQ_DONE_EC, COLOR_$LOAD_MAP | none: hand assembly, `sau5/color_asm.s`, `sau4/color_asm.s` |

`color.ins.pas`, the home of the COLOR declarations: the statuses, the
board's commands, vector and I/O map entries, the cursor bitmap's formal
type, COLOR_$IQ_DONE_EC, the hand-written routines' headings and the
module's.  os/os.pas and smd/smd.pas include it.  The board's register
pages (COLOR_SUP, COLOR_CSTORE) and the display memory (DISP2_MEM) are
SMD's declarations (`../smd/smd_internal.ins.pas`, smd_color_sup_t, now
with the fields COLOR uses), which `color.pas` includes after
`color.ins.pas`; the I/O map (IOMAP) is PBU's (`../pbu/pbu.ins.pas`).
