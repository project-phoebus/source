# The COLOR subsystem in Domain Pascal

The color graphics board's driver of the SAU4 and SAU5 machines (the
part `color_board`, `../base/config.ins.pas`), translated from the SAU5
image.

## Layout

One module, `color.pas`, `module color;` (the map segments' name); its
whole body is under `color_board`, so other SAUs compile it to nothing.

| section | SAU5 segment | routines | attribute |
|---------|--------------|----------|-----------|
| WIRED_PROC | COLOR, 0x24 bytes | COLOR_$VIDEO_CTL | `[section(wired_proc, wired_data)]` |
| OS_INIT_PROC | COLOR, 0x70 bytes | COLOR_$COLD_INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT (default) | COLOR, 0x440 bytes | COLOR_$INT_INIT .. COLOR_$INQ_DONE_WAIT | none |
| .DATA (default) | COLOR data, 0x8C bytes | the wired pages, their count, the owner, the associated flag | module variables |
| WIRED_DATA | COLOR_ASM, 0x9C bytes | COLOR_$VECTOR_INIT, COLOR_$INT_DECODE, COLOR_$IQ_DONE_EC, COLOR_$LOAD_MAP | hand assembly, `sau5/color_asm.s` |

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR_$VIDEO_CTL | `video_ctl.pas` |
| COLOR_$COLD_INIT | `cold_init.pas` |
| COLOR_$INT_INIT | `int_init.pas` |
| COLOR_$ASSOC | `assoc.pas` |
| COLOR_$DISSOC | `dissoc.pas` |
| COLOR_$SHUTDOWN | `shutdown.pas` |
| COLOR_$MAP | `map.pas` |
| COLOR_$UNMAP | `unmap.pas` |
| COLOR_$LOAD_CRSR | `load_crsr.pas` |
| COLOR_$INQ_DONE_WAIT | `inq_done_wait.pas` |
| COLOR_$VECTOR_INIT, COLOR_$INT_DECODE, COLOR_$IQ_DONE_EC, COLOR_$LOAD_MAP | none: hand assembly, `sau5/color_asm.s` |

`color.ins.pas`, the home of the COLOR declarations: the statuses, the
cursor bitmap's formal type, COLOR_$IQ_DONE_EC, the hand-written
routines' headings and the module's.  os/os.pas and smd/smd.pas
include it.  The board's register pages (COLOR_SUP, COLOR_CSTORE) and
the display memory (DISP2_MEM) are SMD's declarations
(`../smd/smd_internal.ins.pas`, smd_color_sup_t, now with the fields
COLOR uses), which `color.pas` includes after `color.ins.pas`.

## Open items

- TODO(sau): the SAU4's COLOR code (`color.pas`).
