# The COLOR4 module in Domain Pascal

A display driver that the SR10.2 SAU2 kernel configures out.  The map's
COLOR4 code segment (4 bytes) in the COLOR4_WIRED_PROC section holds
only `COLOR4_$WORTHLESS`, an empty procedure.  It had no earlier
translation.

## Layout

One module, `color4.pas`, `module color4;`, its one routine headed
`[section(color4_wired_proc, color4_$wired_data)]`; no data.  The body is
conditional on `color4_driver` (`base/config.ins.pas`): where the display is
configured out the module is the empty procedure; the driver arm is not
written (`TODO(sau)` in `color4.pas`).

With `display_devices` (the SAU7, SAU8, SAU9) the map's COLOR4_WIRED_PROC
section also holds COLOR4_ASM (0xA8 bytes), hand assembly:
COLOR4_$LOAD_LUT, which loads up to 16 entries of the device's color
lookup table, and the marker COLOR4_$END_WIRED_PROC on its last word
(`m68k/color4_asm.s`, which assembles to nothing on the other SAUs).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR4_$WORTHLESS | `worthless.pas` |
| COLOR4_$LOAD_LUT | none: hand assembly (COLOR4_ASM, `m68k/color4_asm.s`) |
| COLOR4_$END_WIRED_PROC | none: hand assembly (a marker word in `m68k/color4_asm.s`) |

## Open items

- TODO(sau): the driver's wired code for the SAUs that have the display
  (the other SAUs' maps show their segments).
