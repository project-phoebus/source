|
| ec/m68k/nil_ec.s - EC_$NIL_EC, the nil eventcount, an absolute symbol
|
| The SAU2 and SAU5 images have the same code here; the address and
| byte columns below are the SAU2 image's.
|
| SAU2 map: "D40 0 ABSOLUTE loaded at 0, size = 0" holds one symbol,
| "0 EC_$NIL_EC MARKED" - the binder's ABSOLUTE section, not the TRAP_PAGE
| segment that follows it at the same address (whose vectors are
| arch/m68k/sau2/iodefs.s's).  EC_$WAIT callers pass its address for an
| unused entry (ec/ec.ins.pas): the image's `move.l #0' / `movea.l #0'
| immediates there are fixup-table cells,
| relocations against this symbol, so it is defined here as an absolute
| global, as iodefs.s defines the map's other absolutes.
|
        .globl  EC_$NIL_EC
        .equ    EC_$NIL_EC, 0x00000000
