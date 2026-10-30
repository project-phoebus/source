{ net_io/net_io.pas - the NET_IO module, the network drivers' send and
  receive paths.

  Image addresses:
    sau2  0x00E244F0  NET_IO data (WIRED_DATA, 0xAC bytes)

  One compilation unit, `module net_io, wired_proc, wired_data;': the
  map's NET_IO code segment in WIRED_PROC (net_io_$put_in_sock_common ..
  NET_IO_$SEND) and its data segment in WIRED_DATA (172 bytes).
  NET_IO_UNWIRED is net_io/net_io_unwired.pas.

  The data, the map's globals:
    +0x00  NET_IO_$ALL_F_ADDR      4 bytes, 16#000FFFFF
    +0x04  NET_IO_$NIL_DRIVER      80 bytes, NET_IO_$CLEANUP_NIL its
                                   proc2_cleanup entry
    +0x54  NET_IO_$USER_DRIVER     80 bytes, its entries
                                   ROUTE_$SEND_USER_PORT and others

    +0xA4  RING_$OVERFLOW_OVERFLOW 2 bytes, counted by the worker
    +0xA6  RING_$FILE_OVERFLOW     2 bytes, likewise
    +0xA8  RING_$DELIVERY_FAILED   2 bytes, likewise
    +0xAA  (2 bytes of rounding)
  The driver records' UIDs are filled by NET_IO_$BOOT_DEVICE.

  The routines live in one fragment file each (net_io/<name>.pas),
  included below in image order; every call goes backward.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/net_io/net_io.pas.  Check: tools/pascal_check.sh.
}
module net_io, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'net/net.ins.pas';
%include 'ring/ring.ins.pas';
%include 'ring/ringlog.ins.pas';
%include 'net_io/net_io.ins.pas';

{ The globals this module defines (ref 7.2.2 and 7.3.4, Method 2): the
  block's variables in its order, with the image's bytes, then the
  routines in map order. }
define
  net_io_$all_f_addr := 16#000FFFFF;              { +0x00 }
  net_io_$nil_driver := [unknown0 := 2,
                         max_data_len := 4096,
                         mtu := 16#1400,
                         proc2_cleanup := addr(net_io_$cleanup_nil)];
                                                   { +0x04 }
  net_io_$user_driver := [unknown0 := 2,
                          max_data_len := 1024,
                          sendp := addr(route_$send_user_port),
                          get_stats := addr(route_$read_user_stats),
                          proc2_cleanup := addr(net_io_$cleanup_user)];
                                                   { +0x54 }
  ring_$overflow_overflow;                         { +0xA4, zero }
  ring_$file_overflow;                             { +0xA6 }
  ring_$delivery_failed;                           { +0xA8 }
  net_io_$put_in_sock;
  net_io_$put_in_sock_int;
  net_io_$copy_packet;
  net_io_$send;

{ ---- WIRED_PROC ---- }
%include 'net_io/put_in_sock_common.pas';   { net_io_$put_in_sock_common }
%include 'net_io/put_in_sock.pas';          { NET_IO_$PUT_IN_SOCK }
%include 'net_io/put_in_sock_int.pas';      { NET_IO_$PUT_IN_SOCK_INT }
%include 'net_io/copy_packet.pas';          { NET_IO_$COPY_PACKET }
%include 'net_io/send.pas';                 { NET_IO_$SEND       }
