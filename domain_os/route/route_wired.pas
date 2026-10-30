{ route/route_wired.pas - the ROUTE_WIRED module: the routing ports' wired
  lookups and the wired block of the routing state (the routing socket,
  its eventcount values, the control eventcount, the routing port
  counts, the port pointer table).

  Image addresses:
    sau2  0x00E26EE4  ROUTE_WIRED data (WIRED_DATA, 0x3C bytes)
    sau2  0x00E2E0A0  ROUTE_$PORT (NET_PORT_TABLE, 0x2E0 bytes)

  One compilation unit, in one code section and one data section: the
  map's ROUTE_WIRED code segment in WIRED_PROC (0x98 bytes,
  ROUTE_$FIND_PORT, ROUTE_$FIND_PORTP) and its data segment in
  WIRED_DATA (0x3C bytes, every object a map symbol), and the overlay
  section NET_PORT_TABLE (below).

  The routing code is three map modules (route/README.md):
  ROUTE_WIRED here, ROUTE_UNWIRED and ROUTE_RTWIRED; there is no module
  named ROUTE, so no route/route.pas.

  The heading: `module route_wired, wired_proc, wired_data;' (PKT's
  shape, pkt/pkt.pas); the other modules reach the block by its
  address.

  The data, 0x3C bytes:

    +0x00  ROUTE_$SOCK_ECVAL          4  zero
    +0x04  ROUTE_$PORTP            4*8  the addresses of ROUTE_$PORT's
                                        eight records, 0x5C apart
    +0x24  ROUTE_$CONTROL_ECVAL       4  zero
    +0x28  ROUTE_$CONTROL_EC       0x0C  zero (EC_$INIT'd by the routing
                                        start)

    +0x34  ROUTE_$SOCK                2  -1: no routing socket
    +0x36  ROUTE_$STD_N_ROUTING_PORTS 2  zero
    +0x38  ROUTE_$N_ROUTING_PORTS     2  zero
    +0x3A  ROUTE_$ROUTING             1  zero (false)
    +0x3B  (the block's rounding to 4)

  Build: dpc -I domain_os domain_os/route/route_wired.pas.  Check:
  tools/pascal_check.sh.
}

{ NET_PORT_TABLE: ROUTE_ defines it, below.

  ROUTE_$PORT (map symbol, MARKED) is the start of the map's load
  section NET_PORT_TABLE (0x2E0 bytes), with no module segment in it (an
  overlay section, ref 3.14), eight 0x5C-byte port records, at the same
  address as NETWORK_$ME and DCTE_$NULL.  The image's bytes there are
  zero but for each record's port_type 1 and socket 16#FFFF at +0x2E,
  so some unit gives it initial values (ref 3.14: a `define' of an
  `extern' variable of a `var (name)' part allocates it in the
  section).  Which unit is not known; ROUTE's names the records
  (route_$port_t), so it gives them here. }

module route_wired, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';

{ The module's own variables, every one a map symbol defined here (ref
  7.2.2 and 7.3.4, Method 2), in the order of the block (above); then the
  routines in map order. }
define
  route_$sock_ecval;                                    { +0x00, zero }
  route_$portp := [addr(route_$port[0]), addr(route_$port[1]),
                   addr(route_$port[2]), addr(route_$port[3]),
                   addr(route_$port[4]), addr(route_$port[5]),
                   addr(route_$port[6]), addr(route_$port[7])];
                                                        { +0x04 }
  route_$control_ecval;                                 { +0x24, zero }
  route_$control_ec;                                    { +0x28, zero }
  route_$sock := -1;                                    { +0x34 }
  route_$std_n_routing_ports;                           { +0x36, zero }
  route_$n_routing_ports;                               { +0x38, zero }
  route_$routing;                                       { +0x3A, zero }

{ The overlay section NET_PORT_TABLE (route/route.ins.pas's `var
  (net_port_table)' part): ROUTE_$PORT, eight 0x5C-byte port records,
  zero but for each record's port_type 1 and socket 16#FFFF at +0x2E.
  NETWORK_$ME and DCTE_$NULL, the map's other names at ROUTE_$PORT's
  address, are the link script's aliases of ROUTE_$PORT: one variable
  has one name. }
define
  route_$port := [8 of [port_type := 1, socket := -1]];

define
  route_$find_port;
  route_$find_portp;

{ ---- WIRED_PROC ---- }
%include 'route/find_port.pas';             { ROUTE_$FIND_PORT  }
%include 'route/find_portp.pas';            { ROUTE_$FIND_PORTP }
