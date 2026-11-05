# The IOMAP subsystem in Domain Pascal

The AT bus's I/O map: a word entry per 1 KB page of bus address, the
page number of the memory page that bus page reaches, 0 for none.  The
drivers of the AT bus's controllers map their transfers' pages into it
and clear the entries when the transfers are done.

## Layout

One module, `iomap.pas`, `module iomap_;` (the map segments' name),
present with the part `iomap_routines` (`base/config.ins.pas`):

| section      | code               | routines                              | attribute                                   |
|--------------|--------------------|---------------------------------------|---------------------------------------------|
| WIRED_PROC   | IOMAP_, 0xB8 bytes | IOMAP_$MAP, IOMAP_$READ, IOMAP_$UNMAP | `[section(wired_proc, wired_data)]` on each |
| OS_INIT_PROC | IOMAP_, 0x18 bytes | IOMAP_$INIT                           | `[section(os_init_proc, os_init_data)]`     |

No data segment.  The map is the I/O space's IOMAP, declared in
`pbu/pbu.ins.pas` as 1024 `pinteger` entries with `word_iomap`.

## Routines and their fragments

| routine      | fragment    |
|--------------|-------------|
| IOMAP_$MAP   | `map.pas`   |
| IOMAP_$READ  | `read.pas`  |
| IOMAP_$UNMAP | `unmap.pas` |
| IOMAP_$INIT  | `init.pas`  |

`iomap.ins.pas`: the page list type and the four headings, which the
WIN7_, FLP_, SCSI_, CT_, RING_8025_ and PBU modules include.

## Open items

- IOMAP_$MAP and IOMAP_$UNMAP: 4 frame bytes and an entry load of the
  bus number that no statement explains (the TODO in each).
- Nothing in the kernel calls IOMAP_$READ or IOMAP_$INIT.
