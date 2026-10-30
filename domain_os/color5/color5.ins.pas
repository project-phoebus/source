{ color5/color5.ins.pas - COLOR5 routine headings, for the Domain Pascal tree.

  The COLOR5 display driver is configured out of the SR10.2 SAU2 kernel;
  what is left is the empty COLOR5_$WORTHLESS (the COLOR5 module,
  color5/color5.pas).  Apollo's customer insert files of SR10.2 declare
  nothing of COLOR5.  Include base/base.ins.pas before it.
}

{ COLOR5_$WORTHLESS (color5/worthless.pas): an empty procedure, with no
  parameters. }
procedure color5_$worthless; extern;
