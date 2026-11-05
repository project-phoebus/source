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
| dtty_$gpu_command | `gpu_command.pas` (internal; `dtty_gpu`) |
| dtty_$color_command | `color_command.pas` (internal; `dtty_color_board`) |
| dtty_$color_clear_window | `color_clear_window.pas` (internal; `dtty_color_board` or `dtty_gpu`) |
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

## The SAU4

With `dtty_color_board` the display TTY drives the COLOR_ board's
display itself: dtty_$get_disp_type is a procedure that waits, on a
color display, until the board is idle; the module-local
dtty_$color_command (the board's mode word back, then a command's
words) and dtty_$color_clear_window (the board's clear command)
follow it, dtty_$clear_window clears a color display's window through
them, and dtty_$load_font sends the board its mode word first.
DTTY_$INIT is the `second_display_unit` form.  The WIRED_PROC segment
is 0x2E4 bytes, the data block the SAU2's 0xC.

## The SAU6

With `dtty_gpu` the display TTY drives the graphics processor's color
displays (smd_$color2_display, the DN580's; smd_$color3_display, the
DN570's) itself, through the processor's control block at KOLOR_CTL:
dtty_$get_disp_type waits until the processor is done (status member
14), the module-local dtty_$gpu_command sends it commands (the DN580's
through its count, argument and operation registers, the DN570's
through its FIFO as its free count allows) and then waits,
dtty_$color_clear_window sends the processor's clear command, 16#E000,
dtty_$clear_window clears a color display's window through it, and
dtty_$load_font sends the processor's font command, 16#48B0, first.
The processor is there when SMD_$GRAPHIC_DEVICE_ID is 1 or 2.  The
WIRED_PROC segment is 0x3AC bytes (six module-local routines), the data
block the SAU2's 0xC; DTTY_$INIT is the `gpu_driver` form without
`second_display_unit`.  The SAU5's segment has this form and the color
board's together (the TODO(sau) in `dtty.pas`).

## The SAU3

Without `display_driver` (the DSP has no display) the map's DTTY unit is
DTTY_$INIT alone (OS_INIT_PROC, 0x1C bytes: the control word and
DTTY_$USE_DTTY := true) and a 4-byte block (DTTY_$CTRL +0x00,
DTTY_$USE_DTTY +0x02); there is no WIRED_PROC code.  `dtty.pas` puts
the WIRED_PROC routines and dtty_$disp_type, dtty_flag_04, dtty_flag_06
under the part; `init.pas` has the short arm (its frame TODO(pascal)
says how its 0x2C bytes are filled).  DTTY_WIRED and DTTY_ASM (hand
assembly) are the SAU2's.

## The SAU7

The SAU7's DTTY (WIRED_PROC 0x1A0 bytes, OS_INIT_PROC 0x128, the data
block 0xC) is the SAU9's code (`smd_display_memory`), and its
hand-written DTTY_WIRED and DTTY_ASM are `m68k/`'s with the SAU9's
parts (`trap_page_high`): no SAU7 source.

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

### TODO(sau)

- `dtty.pas`: the SAU5's WIRED_PROC routines (the color board's and the
  graphics processor's forms together).

### TODO(pascal)

- `init.pas`: 36 frame bytes (stand-ins `unused_20`, `unused_40`,
  `unused_44`).
- `gpu_command.pas`: 12 frame bytes nothing addresses.
