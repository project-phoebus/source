# The COLOR7 module in Domain Pascal

A display driver that the SR10.2 SAU2 kernel configures out.  The map's
4-byte COLOR7 code segment, in the COLOR7_WIRED_PROC section, holds
only `COLOR7_$WORTHLESS`, an empty procedure and the module-end filler.

## Layout

One module, `color7.pas`, `module color7;`, its one routine headed
`[section(color7_wired_proc, color7_$wired_data)]`; no data.  The body is
conditional on `color7_driver` (`base/config.ins.pas`): where the display is
configured out the module is the empty procedure; the driver arm is not
written (`TODO(sau)` in `color7.pas`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR7_$WORTHLESS | `worthless.pas` |

## Open items

- TODO(sau): the driver's wired code for the SAUs that have the display
  (`color7/color7.pas` describes the other SAUs' map segments).
