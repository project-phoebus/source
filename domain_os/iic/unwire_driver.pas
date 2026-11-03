{ iic_unwire_driver - unwire the driver's code and data.

  Image addresses:
    sau3  0x00E712C8  iic_unwire_driver (module-local)

  Status stored: none.
}

procedure iic_unwire_driver; internal;
var
  i: integer;
begin
  for i := 1 to iic_wire_count do
    wp_$unwire(iic_wire_list[i]);
  iic_wire_count := 0;
end;
