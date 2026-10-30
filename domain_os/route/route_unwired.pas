{ route/route_unwired.pas - the ROUTE_UNWIRED module: the routing
  service (opening, changing and closing routing ports, starting the
  routing process), the port summary, the eventcounts and statistics of
  the routing ports, the shutdown of every port, and the wiring of the
  routing code and data.

  Image addresses:
    sau2  0x00E825DC  ROUTE_UNWIRED data (.DATA, 0x8 bytes)

  One compilation unit, in the default sections: the map's ROUTE_UNWIRED
  code segment in .TEXT (0xB88 bytes, two module-local helpers and
  ROUTE_$SHORT_PORT .. ROUTE_$READ_USER_STATS) and its data segment in
  .DATA (8 bytes), so `module route_unwired;' (msg/msg_unwired.pas's
  shape).

  The data, 8 bytes:

    +0x00  ROUTE_$START_TIME          4  zero; defined here
    +0x04  route_$announce_template   2  2: route_$announce_net's packet
    +0x06  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each (route/<name>.pas),
  included below in image order: route_$cleanup_wired and
  route_$wire_routing_area, ROUTE_$SHORT_PORT, ROUTE_$GET_EC,
  ROUTE_$SERVICE with its four nested routines, ROUTE_$SHUTDOWN and
  ROUTE_$READ_USER_STATS.

  Build: dpc -I domain_os domain_os/route/route_unwired.pas.  Check:
  tools/pascal_check.sh.
}

module route_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';
%include 'app/app.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'hint/hint.ins.pas';

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
define
  route_$start_time;                                    { +0x00, zero }

var
  route_$announce_template: integer := 2;               { +0x04 }

define
  route_$short_port;
  route_$get_ec;
  route_$service;
  route_$shutdown;
  route_$read_user_stats;

{ ---- .TEXT ---- }
%include 'route/cleanup_wired.pas';         { route_$cleanup_wired     }
%include 'route/wire_routing_area.pas';     { route_$wire_routing_area }
%include 'route/short_port.pas';            { ROUTE_$SHORT_PORT        }
%include 'route/get_ec.pas';                { ROUTE_$GET_EC            }
%include 'route/service.pas';               { ROUTE_$SERVICE and its
                                              four nested routines     }
%include 'route/shutdown.pas';              { ROUTE_$SHUTDOWN          }
%include 'route/read_user_stats.pas';       { ROUTE_$READ_USER_STATS   }
