{ lpr/lpr.ins.pas - LPR (line printer) routine headings, for the Domain
  Pascal tree.

  The line printer driver is configured out of the SR10.2 SAU2 kernel;
  what is left is LPR_$RELEASE, hand-written assembly (the map's LPR_ASM
  code segment, 4 bytes; lpr/README.md).  Include
  base/base.ins.pas before it.
}

{ LPR_$RELEASE - release a line printer unit.  On the SAU2 a bare return
  (lpr/m68k/release.s): the body shows nothing of the parameters.  The
  one caller, PROC2_$CLEANUP_HANDLERS_INTERNAL, passes two addresses: a
  constant word cell, then its status.

  A constant by address is a literal passed to an `in' parameter: the unit,
  `in'.  Its type is boolean, the literal `false': PROC2_$GET_ASID passes
  the same cell as PROC2_$FIND_ASID's `in' boolean use_alt, and a later
  routine shares an earlier cell only for a literal of the same bytes and
  type (`false' in the word's high byte).  CT_$RELEASE's unit, an integer 0,
  has a cell of its own.  `dpc -o' pools GET_ASID's `false' with this cell
  as the image does.  The status is `out', the form of every status
  parameter.  The default convention (everything by address), no options. }
procedure lpr_$release(in unit: boolean; out status_ret: status_$t); extern;
