{ COLOR2_$INT_INIT - define the graphics board's color interrupt.

  Image addresses:
    sau5  0x00E73184  COLOR2_$INT_INIT

  - On the SAU5, COLOR_ASM's COLOR_$VECTOR_INIT: its decoder,
    COLOR_$INT_DECODE, advances COLOR2_$INT_EC for the board's vectors
    (color/sau5/color_asm.s).

  Status stored: none.
}

procedure color2_$int_init;
begin
%if color_board %then
  color_$vector_init;
%else
  { TODO(sau) the SAU6's COLOR2_$INT_INIT (no COLOR_ASM there) }
%endif
end;
