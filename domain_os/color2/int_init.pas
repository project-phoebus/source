{ COLOR2_$INT_INIT - define the graphics board's color interrupt.

  Image addresses:
    sau5  0x00E73184  COLOR2_$INT_INIT
    sau6  0x7807A014  COLOR2_$INT_INIT

  - On the SAU5, COLOR_ASM's COLOR_$VECTOR_INIT: its decoder,
    COLOR_$INT_DECODE, advances COLOR2_$INT_EC for the board's vectors
    (color/sau5/color_asm.s).
  - With `gpu_own_vectors' (base/config.ins.pas) COLOR2_$INT_DECODE goes
    in the board's own vector, COLOR2_DONE_VEC.

  Status stored: none.
}

procedure color2_$int_init;
begin
%if color_board %then
  color_$vector_init;
%elseif gpu_own_vectors %then
  color2_done_vec := addr(color2_$int_decode);
%endif
end;
