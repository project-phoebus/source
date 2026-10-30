{ NETWORK_$GET_PKT_SIZE - the packet size to use for a destination.

  Image addresses:
    sau2  0x00E0FA00  NETWORK_$GET_PKT_SIZE

  - A size of 1024 is taken as it is, and a destination on another
    internet gets 1024.
  - Otherwise the size is RIP_$FIND_NEXTHOP's answer for a direct route
    on an active port, 1024 for any other route or a failed lookup, and
    the caller's for this node.
  - The result is cut to the caller's size, then raised to 1024.

  Status stored: none.
}

{ TODO(pascal) a direct route's 1024 and the dead driver load

  On a direct route's inactive port the image sets the result through
  another register and loads the port's driver record into a register
  nothing reads.  Written as two register locals (psize, drv) assigned
  in that order and the result from psize; no construct that would
  explain the detour (a `with' of the driver record, an expression on
  one of its fields that was later removed) is known. }

{ TODO(pascal) NETWORK_$GET_PKT_SIZE's frame offsets against dpc's

  The image: dest -0x10, nexthop -0x20, host -0x28, status -0x2C, port
  -0x32, frame 0x38.  dpc (with the register locals' slots after them)
  gives the frame 0x38 but dest -0x10, nexthop -0x1C, host -0x20, status
  -0x24, port -0x26 (a probe unit, network/README.md).  The
  image's nexthop is 8-aligned, and 4 bytes lie between it
  and host and 4 between status and port: where the register locals'
  slots go is not known. }

function network_$get_pkt_size(in node: uid_$t; size: pinteger): pinteger;
label
  10, 20, 30;
var
  dest: rip_$dest_addr_t;
  nexthop: rip_$nexthop_t;
  host: linteger;
  status: status_$t;
  port: integer;
  rip_result: integer;
  port_index: integer;
  psize: pinteger;
  sz: pinteger;
  p: route_$port_ptr_t;
  drv: net_io_$driver_ptr_t;
begin
  if size = 1024 then goto 20;
  if (node.high <> network_$me) and then (node.high <> 0) then
    goto 30;

  { ask RIP }
  if network_$loopback_flag then
    host := node_$me
  else
    host := node.low;
  dest.network := node.high;
  dest.host_node := host;
  rip_result := rip_$find_nexthop(dest, false, port, nexthop, status);
  port_index := port;
  sz := rip_result;
  if status.all <> status_$ok then
    sz := 1024;

  { this node }
  if host = node_$me then begin
20:
    sz := size;
    goto 10;
  end;

  { the route }
  if rip_result <> 0 then goto 30;
  p := route_$portp[port_index];
  if p^.active <> 1 then begin
    psize := 1024;
    drv := net_io_$driver_ptr_t(p^.driver_info);
    sz := psize;
  end
  else
    status.all := status_$network_request_denied_by_local_node;
  goto 10;

30:
  sz := 1024;

10:
  if sz > size then
    sz := size;
  if sz <= 1024 then
    sz := 1024;
  network_$get_pkt_size := sz;
end;
