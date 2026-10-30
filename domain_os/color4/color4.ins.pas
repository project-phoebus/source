{ color4/color4.ins.pas - COLOR4 routine headings, for the Domain Pascal
  tree.

  The COLOR4 display driver is configured out of the SR10.2 SAU2 kernel;
  what is left is the empty COLOR4_$WORTHLESS (the COLOR4 module,
  color4/color4.pas).  It had no earlier translation.  Apollo's customer
  insert files of SR10.2 declare nothing of COLOR4.  Include
  base/base.ins.pas before it.
}

{ COLOR4_$WORTHLESS - the empty procedure of a configured-out driver. }
procedure color4_$worthless; extern;
