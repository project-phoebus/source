{ NETWORK_$LOAD - attach the network service to port 0's driver.

  Image addresses:
    sau2  0x00E2F7F2  NETWORK_$LOAD

  - When port 0 is active and its driver has an entry at +0x1C, the
    entry is called for port 0's socket with a zero service record and
    request 0; a failure crashes the system.

  Status stored: none.
}

{ TODO(pascal) NETWORK_$LOAD's frame: out4 and 6 more bytes

  The image has status at -0x4 and out4 at -0xA in a frame of 16 bytes;
  dpc places out4 at -0x6 and drv's slot at -0xC, frame 0xC.  Either
  out4 is wider than a word (the driver's own record; route/service.pas
  has a longword for the same entry's slot) or other locals lie between;
  the 4 bytes at -0x8 and the 6 at -0x10 are addressed by nothing. }

[section(os_init_proc, os_init_data)]
procedure network_$load;
var
  status: status_$t;
  out4: integer;
  drv: net_io_$driver_ptr_t;
begin
  with route_$port[0] do
    if active <> 0 then begin
      drv := net_io_$driver_ptr_t(driver_info);
      if drv^.detach <> nil then begin
        network_$service_proc_t(drv^.detach)^(socket, 0, 0, out4, status);
        if status.all <> status_$ok then
          crash_system(status);
      end;
    end;
end;
