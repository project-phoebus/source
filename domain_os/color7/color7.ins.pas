{ color7/color7.ins.pas - COLOR7 routine headings, for the Domain Pascal tree.

  The COLOR7 display driver is configured out of the SR10.2 SAU2 kernel;
  what is left is the empty COLOR7_$WORTHLESS (the COLOR7 module,
  color7/color7.pas).  Apollo's customer insert files of SR10.2 declare
  nothing of COLOR7.  Include base/base.ins.pas before it.
}

{ COLOR7_$WORTHLESS - the empty procedure of a configured-out driver. }
procedure color7_$worthless; extern;
