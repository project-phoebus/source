{ FLP_$SHUT_DOWN_MOTOR - switch the drives' motor off.

  Image addresses:
    sau8  0x03C45A84  FLP_$SHUT_DOWN_MOTOR

  - The digital output gets 16#0C: DMA and the controller on, the
    motors off.

  Status stored: none.
}

procedure flp_$shut_down_motor;
begin
  flp_hw_addr^.dor := 16#0C;
end;
