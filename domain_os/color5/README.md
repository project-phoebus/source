# The COLOR5 module in Domain Pascal

A display driver that the SR10.2 SAU2 kernel configures out.  The map's
COLOR5 code segment (4 bytes) in the COLOR5_WIRED_PROC section holds
only `COLOR5_$WORTHLESS`, an empty procedure, and the module-end filler.

## Layout

One module, `color5.pas`, `module color5;`, its one routine headed
`[section(color5_wired_proc, color5_$wired_data)]`; no data.  The body is
conditional on `color5_driver` (`base/config.ins.pas`): where the display is
configured out the module is the empty procedure; the driver arm is not
written (`TODO(sau)` in `color5.pas`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| COLOR5_$WORTHLESS | `worthless.pas` |

## Open items

- TODO(sau): the driver's wired code for the SAUs that have the display
  (the other SAUs' maps show their segments).
