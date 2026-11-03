{ IIC_$INIT - initialize the internet interface controller.

  Image addresses:
    sau2  0x00E70A54  IIC_$INIT
    sau3  0x00E32FA0  IIC_$INIT

  - Without the driver an empty procedure.
  - With it, the driver record gets the network's UID, and each line
    that is present gets a NET_IO port (route_$port_type_iic).

  Status stored: none.
}

%if iic_driver %then
[section(os_init_proc, os_init_data)]
%endif
procedure iic_$init;
%if iic_driver %then
var
  status: status_$t;
  line: pinteger;
%endif
begin
%if iic_driver %then
  iic_driver.network_uid := iic_$network_uid;
  for line := 0 to iic_$max_line do
    if iic_$exists(line) then
      iic_port[line] := net_io_$create_port(route_$port_type_iic, line,
                                            addr(iic_driver), 0,
                                            status);
%endif
end;
