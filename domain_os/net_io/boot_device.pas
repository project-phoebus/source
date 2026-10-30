{ NET_IO_$BOOT_DEVICE - record the network boot device.

  Image addresses:
    sau2  0x00E31C14  NET_IO_$BOOT_DEVICE

  - The NIL and USER driver records get their network UIDs; a network
    boot device (2 and 3 type 0, 6 type 4, 8 type 5) has its unit and
    port type recorded.  The result is true for one (a diskless node).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function net_io_$boot_device(boot_device: integer; boot_unit: integer):
  boolean;
  options(val_param);
begin
  net_io_$nil_driver.network_uid := nil_$network_uid;
  net_io_$user_driver.network_uid := user_$network_uid;

  net_io_$boot_device := true;
  if (boot_device = 2) or else (boot_device = 3) then
    net_io_$boot_port_type := route_$port_type_ring
  else if boot_device = 6 then
    net_io_$boot_port_type := 4
  else if boot_device = 8 then
    net_io_$boot_port_type := 5
  else begin
    net_io_$boot_device := false;
    return;
  end;
  net_io_$boot_unit := boot_unit;
end;
