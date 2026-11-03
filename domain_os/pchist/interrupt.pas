{ PCHIST_$INTERRUPT - record a sample of the program counter from an
  interrupt.

  Image addresses:
    sau2  0x00E1A1F6  PCHIST_$INTERRUPT
    sau4  0x0F81AE5E  PCHIST_$INTERRUPT

  - PCHIST_$COUNT in mode 1.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure pchist_$interrupt(in pc: integer32);
var
  unused_4: integer32;                    { stand-in }
begin
  pchist_$count(pc, 1);
end;
