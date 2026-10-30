{ DUMMY_INTERRUPT_HANDLER - an interrupt routine that claims every
  interrupt.

  Image addresses:
    sau2  0x00E6D46C  DUMMY_INTERRUPT_HANDLER

  - The result true is an interrupt routine's "handled" (FLP_$INT,
    WIN_$INT).

  Status stored: none.
}

function dummy_interrupt_handler: boolean;
begin
  dummy_interrupt_handler := true;
end;
