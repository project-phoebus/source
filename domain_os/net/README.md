# The NET subsystem in Domain Pascal

The network device abstraction layer.

## Layout

One module, `net.pas`, `module net;` (the map segment's name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | NET, 0x274 bytes | net_$find_handler (module-local), NET_$GET_INFO, NET_$OPEN, NET_$CLOSE, NET_$IOCTL, NET_$RCV, NET_$SEND | none |

No data: the map has no NET data segment and no routine loads A5.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| net_$find_handler | `find_handler.pas`, `internal` (no map symbol; the map's NET segment starts here, NET_$GET_INFO the first symbol) |
| NET_$GET_INFO | `get_info.pas` |
| NET_$OPEN | `open.pas` |
| NET_$CLOSE | `close.pas` |
| NET_$IOCTL | `ioctl.pas` |
| NET_$RCV | `rcv.pas` |
| NET_$SEND | `send.pas` |

No routine is nested.  `net.ins.pas`: the two status codes, the opaque
argument type, the driver entries' two shapes (routine pointer types,
`val_param`) and the six headings (the default convention; the
dispatchers pass their by-address slots on to the drivers).
net_$find_handler's heading is its body's (`internal`, by value: three
words and the status), before its callers in `net.pas`.

Changes to shared insert files:
- `net_io/net_io.ins.pas`: net_io_$driver_t (its entries univ_ptr) and
  NET_IO_$NIL_DRIVER.
- `route/route.ins.pas`: route_$port_t's driver_info (+0x48), with a
  filler.
- `proc2/proc2.ins.pas`: PROC2_$SET_CLEANUP.

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

The word below the arguments of the calls of net_$find_handler and of
the control entries is the pad of 10- and 18-byte argument lists, not a
result slot: the drivers' entries are procedures here.  The entry
offsets are computed at run time from NET_IO_$NIL_DRIVER's addresses,
not constants.

### TODO(pascal)

None.
