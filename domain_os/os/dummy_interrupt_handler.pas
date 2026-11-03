{ DUMMY_INTERRUPT_HANDLER - an interrupt routine that claims every
  interrupt.

  Image addresses:
    sau2  0x00E6D46C  DUMMY_INTERRUPT_HANDLER
    sau3  0x00E6D846  DUMMY_INTERRUPT_HANDLER
    sau4  0x0F876F68  DUMMY_INTERRUPT_HANDLER
    sau8  0x03C76810  DUMMY_INTERRUPT_HANDLER

  - The result true is an interrupt routine's "handled" (FLP_$INT,
    WIN_$INT).

  Status stored: none.
}

function dummy_interrupt_handler: boolean;
begin
  dummy_interrupt_handler := true;
end;
