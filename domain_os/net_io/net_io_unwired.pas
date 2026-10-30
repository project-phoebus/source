{ net_io/net_io_unwired.pas - the NET_IO_UNWIRED module, the network
  ports' set-up, statistics and cleanup.

  Image addresses:
    sau2  0x00E81668  NET_IO_UNWIRED data (.DATA, 0x14 bytes)

  One compilation unit, `module net_io_unwired;': the map's
  NET_IO_UNWIRED code segments in OS_INIT_PROC (NET_IO_$BOOT_DEVICE,
  NET_IO_$INIT), .TEXT (NET_IO_$DEVICE_STAT .. NET_IO_$CREATE_PORT) and
  PROC2_DELETE_PRO (NET_IO_$FREE_ASID and the two cleanup routines),
  each headed with its sections, and its data segment in .DATA (20
  bytes).

  The data, zero but net_io_$boot_unit:
    +0x00  net_io_$port_asid       16 bytes, each port's creating
                                   address space
    +0x10  net_io_$boot_unit       2 bytes, 16#03E7 (net_io_$no_boot_unit)
    +0x12  net_io_$boot_port_type  2 bytes

  The routines live in one fragment file each (net_io/<name>.pas),
  included below in image order; the cleanup routines are reached
  through NET_IO's driver records.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/net_io/net_io_unwired.pas.  Check: tools/pascal_check.sh.
}
module net_io_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'net_io/net_io.ins.pas';

{ The module's own variables (ref 3.2), in the order of the block
  (above), and the globals it defines (ref 7.3.4, Method 2), the
  routines in map order. }
var
  net_io_$port_asid: array[0..7] of integer;      { +0x00, zero }
  net_io_$boot_unit: integer := net_io_$no_boot_unit;
                                                   { +0x10: 16#03E7 }
  net_io_$boot_port_type: integer;                 { +0x12, zero }

define
  net_io_$boot_device;
  net_io_$init;
  net_io_$device_stat;
  net_io_$device_stat2;
  net_io_$create_port;
  net_io_$free_asid;
  net_io_$cleanup_nil;
  net_io_$cleanup_user;

{ ---- OS_INIT_PROC ---- }
%include 'net_io/boot_device.pas';          { NET_IO_$BOOT_DEVICE }
%include 'net_io/init.pas';                 { NET_IO_$INIT }

{ ---- .TEXT ---- }
%include 'net_io/device_stat.pas';          { NET_IO_$DEVICE_STAT }
%include 'net_io/device_stat2.pas';         { NET_IO_$DEVICE_STAT2 }
%include 'net_io/create_port.pas';          { NET_IO_$CREATE_PORT }

{ ---- PROC2_DELETE_PRO ---- }
%include 'net_io/free_asid.pas';            { NET_IO_$FREE_ASID }
%include 'net_io/cleanup_nil.pas';          { NET_IO_$CLEANUP_NIL }
%include 'net_io/cleanup_user.pas';         { NET_IO_$CLEANUP_USER }
