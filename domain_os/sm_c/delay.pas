{ sm_c_$delay - wait a little between writes to the controller.

  Image addresses:
    sau3  0x00E6F4A2  sm_c_$delay (module-local)
    sau4  0x0F87C25E  sm_c_$delay (module-local)
    sau5  0x00E75006  sm_c_$delay (module-local)
    sau6  0x7807BD1A  sm_c_$delay (module-local)

  - SM_C_$DINIT calls it after each of its writes to the controller's
    address registers.

  Status stored: none.
}

procedure sm_c_$delay; internal;
var
  i: integer;
  j: integer;
begin
  for i := 1 to 10 do
    j := i div 10;
end;
