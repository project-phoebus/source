{ LOG_INT_ERROR - log a word of the controller's other interrupts.

  Image addresses:
    sau6  0x7801ADC6  LOG_INT_ERROR

  - The word goes to the next of WIN6_$INT_ERS's entries, a ring of 40
    (WIN6_$INT_ERX the last one written).

  Status stored: none.
}

procedure log_int_error(in w: integer);
begin
  if win6_$int_erx = win6_int_ers_size then
    win6_$int_erx := 1
  else
    win6_$int_erx := win6_$int_erx + 1;
  win6_$int_ers[win6_$int_erx] := w;
end;
