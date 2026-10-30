{ flop/flop.ins.pas - FLOP_BOOT (booting from the floppy) types and the
  routine heading, for the Domain Pascal tree.

  The boot shell's header as FLOP_$BOOT copies it and the heading of
  FLOP_$BOOT.  The module is flop/flop.pas.  Include base/base.ins.pas
  before it.
}

type
  { The first six longwords of the mapped boot shell, copied whole into
    FLOP_$BOOT's frame (a 24-byte record assignment, a copy loop).  Its
    first longword is the address MST_$MAP_AT maps at, its second the entry
    point.  An array from 1. }
  flop_$header_t = array[1..6] of integer32;
  flop_$header_ptr_t = ^flop_$header_t;

{ FLOP_$BOOT - boot from the floppy: map the boot shell, return its entry. }
function flop_$boot(out entry_point: integer32;
                    out status_ret: status_$t): boolean;
  extern;
