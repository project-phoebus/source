# The DTTY subsystem in Domain Pascal

The display TTY (the console's output through the PROM and the SMD
display driver).

## Layout

One compiled module, `dtty.pas`, `module dtty, wired_proc, wired_data;`
(the map segments' name), and two hand-written map modules:

| map segment | section, size | what | Pascal |
|-------------|---------------|------|--------|
| DTTY (code) | WIRED_PROC, 0x1C8 (SAU7..SAU9 0x1A0: `smd_display_memory`, dtty_$get_disp_type empty, dtty_$clear_window clears the screen) | four module-local routines, DTTY_$WRITE_STRING, DTTY_$TSTART, DTTY_$RELOAD_FONT | `dtty.pas`, no attribute |
| DTTY (code) | OS_INIT_PROC, 0x15C (SAU5 0x1EC: the color displays' arms, `gpu_driver`, `second_display_unit`; SAU9 0x128: `smd_display_memory`, SMD_$INQ_DISP_INFO) | DTTY_$INIT and its cells | `dtty.pas`, `[section(os_init_proc, os_init_data)]` |
| DTTY (data) | WIRED_DATA, 0xC | the module's variables | `dtty.pas` |
| DTTY_WIRED (data) | WIRED_DATA, 0x48 (SAU7, SAU9 0x4C: `trap_page_high`, the PROM cells absolute long) | hand assembly: DTTY_$PUTC, RELOAD_FONT, DTTY_$CLEAR_SCREEN | none (`m68k/prom_io.s` has two of the three) |
| DTTY_ASM (data) | .DATA, 0x44C | hand assembly and data: DTTY_$ESCAPE, DTTY_$STD_FONT_P, DTTY_$FONT1..3 | none (`m68k/dtty_asm.s`) |

The block, with the map's names defined here:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `dtty_$disp_type` | smd_$display_type_t |
| +0x02 | DTTY_$CTRL (`define`d) | integer |
| +0x04 | `dtty_flag_04` | boolean |
| +0x06 | `dtty_flag_06` | boolean |
| +0x08 | DTTY_$USE_DTTY (`define`d) | boolean |
| +0x09 | 3 bytes: rounding (every map `D` segment is a multiple of 4) | |

WIRED_PROC reaches the block through A5, DTTY_$INIT by its absolute
address held in a register (another section's block, as SUMA_$INIT).
No routine is nested.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| dtty_$get_disp_type | `get_disp_type.pas` (internal function; with `smd_display_memory` an empty procedure) |
| dtty_$clear_window | `clear_window.pas` (internal) |
| dtty_$report_error | `report_error.pas` (internal; its constant cells follow it) |
| dtty_$load_font | `load_font.pas` (internal function; loads A5, called from OS_INIT_PROC) |
| DTTY_$WRITE_STRING | `write_string.pas` |
| DTTY_$TSTART | `tstart.pas` (`val_param`) |
| DTTY_$RELOAD_FONT | `reload_font.pas` |
| DTTY_$INIT | `init.pas` |
| DTTY_$PUTC | none: hand assembly (`m68k/prom_io.s`) |
| DTTY_$CLEAR_SCREEN | none: hand assembly (`m68k/prom_io.s`) |
| RELOAD_FONT | none: hand assembly (DTTY_WIRED; a call through the PROM vector at 0x114, then D0 cleared), module-local, in `dtty/m68k/prom_io.s` |
| DTTY_$ESCAPE | none: hand assembly (DTTY_ASM: a trap and a return; `m68k/dtty_asm.s`) |
| (data) | the block in `dtty.pas`; DTTY_$STD_FONT_P and the font (DTTY_ASM) extern in `dtty.ins.pas` |

## Insert files

- `dtty.ins.pas`: the line record and buffer DTTY_$TSTART drains, its
  callback type, `dtty_$chars_t`; DTTY_$CTRL, DTTY_$STD_FONT_P
  (DTTY_$USE_DTTY was there); the four global headings and DTTY_$PUTC's.
- `smd/smd.ins.pas`: Apollo's `smd_$window_limits_t`, DISP1_MEM
  (`disp1_mem`), SMD_$INQ_DISP_TYPE (Apollo's heading), SMD_$ASSOC,
  SMD_$CLEAR_WINDOW, SMD_$COPY_FONT_TO_MD_HDM.
- `vfmt/vfmt.ins.pas`, `proc1/proc1.ins.pas`: used as they are.

## Open items

### Source forms

- DTTY_$INIT's three error reports are three calls whose tails the
  compiler merged.
- DTTY_$INIT's function-name strings end with VFMT's end-of-text code
  `%$`, the image's bytes (dtty_$report_error's own "... returned from
  %$" has it): each name is VFMT's control string.
- DTTY_$RELOAD_FONT is a procedure; the word result its system-call
  user sees is dtty_$load_font's D0 left in place.
- The buffer's third field is `end_pos` (`end` is a reserved word).

### TODO(pascal)

- `init.pas`: 36 frame bytes (stand-ins `unused_20`, `unused_40`,
  `unused_44`).
