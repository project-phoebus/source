{ iic/iic.pas - the IIC module, the internet interface controller's
  driver.

  Image addresses:
    sau3  0x00E844D8  IIC data (.DATA, 0xAC bytes)
    sau3  0x00E865C8  IIC data (IIC_AQWRD_DATA, 8 bytes)

  One compilation unit.  Where the driver is configured out (the SAU2,
  SAU4..SAU9), one code segment and no data: the map's IIC code segment
  (.TEXT, 0xA0 bytes) holds the nine IIC_ routines, in the order of the
  `define' list's second arm, and the compiled module-end filler; all
  nine are stubs.  The map's IIC_AQWRD_PROC and IIC_AQWRD_DATA sections
  are empty, their four labels IIC_$DATA_START, _$PROC_START, _$PROC_END
  and _$DATA_END at one address.  IIC_$NETWORK_UID is in the UID_LIST
  segment (another unit's data).

  With the driver (`iic_driver', base/config.ins.pas), on the SAU3: the
  driver of a PBU controller with two lines, each a NET_IO port and a
  channel for MAC_OS, with its own guardian process.  The map's IIC code
  segments:

    WIRED_PROC         0xBC    IIC_$EXISTS
    OS_INIT_PROC       0x74    IIC_$INIT
    .TEXT              0xF2C   six module-local routines, then
                               CALL_GUARDIAN, a seventh, IIC_$ACQUIRE ..
                               IIC_$SELF_TEST, and an eighth
    PROC2_DELETE_PRO   0x4C    IIC_$PROC2_CLEANUP
    IIC_AQWRD_PROC     0xE10   iic_command (at IIC_$PROC_START),
                               iic_map_iova, SEND_PACKET, iic_send_link,
                               INTERRUPTER, IIC_$INT, GUARDIAN_PROCESS,
                               IIC_$SENDP, iic_open_internal,
                               IIC_$OPEN_OS .. IIC_$SEND_OS

  and data segments in .DATA (0xAC bytes, the module's variables, below)
  and IIC_AQWRD_DATA (8 bytes, IIC_$SENDP's static).  Two more sections
  hold the driver's objects, overlay sections declared below:
  IIC_AQWRD_DATA2 (0x3B8 bytes: the two lines' records and the driver
  record) and IIC_$CONTROL_PAG (0x2000 bytes at a fixed address in the
  low region, no bytes in the image: the lines' control pages).  The
  driver wires its IIC_AQWRD_PROC code through IIC_AQWRD_DATA (from
  IIC_$PROC_START to IIC_$DATA_END), so its interrupt routine, the
  guardian's receive path and the MAC_OS entries run wired.

  The heading names no section: the .DATA block's objects are module
  variables, reached through A5 in .TEXT and by their address from the
  other sections; the routines of the other sections are headed with
  their sections.

  The data block (.DATA), zero except the values given:

    +0x00  iic_wire_list      the driver's wired pages, 32
    +0x80  iic_port           the lines' NET_IO ports
    +0x84  iic_reset_poll     2 ms (500 ticks), the reset's poll
    +0x8C  iic_reset_hold     1 ms (250 ticks), the reset pulse
    +0x94  iic_stop_wait      1 s (250000 ticks), after a stop
    +0x9A  iic_guardian_line  the line a new guardian serves
    +0x9C  iic_users          the lines started
    +0x9E  iic_wire_count     the count of iic_wire_list
    +0xA0  iic_pbu_acquired   the PBU unit is set up
    +0xA4  iic_send_spacing   1 ms (250 ticks) between two sends

  The clocks are at multiples of 4: the words at +0x8A and +0x92 and
  +0xA1..+0xA3 are where no instruction reaches.

  The routines live in one fragment file each (iic/<name>.pas), included
  below in image order (iic/README.md has the table).

  Check: tools/pascal_check.sh.
}
module iic;

%include 'base/base.ins.pas';
%if iic_driver %then
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'io/io.ins.pas';
%include 'pbu/pbu.ins.pas';
%include 'node/node.ins.pas';
%include 'uid/uid.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'sock/sock.ins.pas';
%include 'os/os.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'route/route.ins.pas';
%include 'rip/rip.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'network/network.ins.pas';
%endif
%include 'iic/iic.ins.pas';

%if iic_driver %then
{ The lines' records and the driver record (the map's IIC_AQWRD_DATA2,
  a load section with no module segment in it, 0x3B8 bytes) and the
  lines' control pages (the map's IIC_$CONTROL_PAG, 0x2000 bytes):
  overlay sections (ref 3.14 p. 3-52; 7.2.4, Method 4).  A line's four
  pages are its command block, its transmit header and data pages and
  its receive data page, the pages of one kind side by side. }
var (iic_aqwrd_data2)
  iic_lines: array[0..iic_$max_line] of iic_$line_t;        { +0x000 }
  iic_driver: iic_$driver_t := [
    unknown0 := 2,
    max_data_len := 1024,
    mtu := 1536,
    unknown6 := chr(0),
    flags := chr(2),
    sendp := addr(iic_$sendp),
    get_stats := addr(iic_$int_statistics),
    get_stats2 := addr(iic_$int_statistics),
    start := addr(iic_$net_start),
    stop := addr(iic_$$release),
    proc2_cleanup := addr(iic_$proc2_cleanup),
    open_os := addr(iic_$open_os),
    close_os := addr(iic_$close_os),
    send_os := addr(iic_$send_os)];                         { +0x368 }
var (iic_$control_pag)
  iic_$control_page: array[0..3] of
                       array[0..iic_$max_line] of iic_$page_t;

{ The module's own variables, in the order of the data block (above). }
var
  iic_wire_list: array[1..32] of integer32;                 { +0x00 }
  iic_port: array[0..iic_$max_line] of integer;             { +0x80 }
  iic_reset_poll: time_$clock_t := [high := 0, low := 500]; { +0x84 }
  unused_8a: integer;                                       { +0x8A }
  iic_reset_hold: time_$clock_t := [high := 0, low := 250]; { +0x8C }
  unused_92: integer;                                       { +0x92 }
  iic_stop_wait: time_$clock_t := [high := 3, low := 16#D090];
                                                            { +0x94 }
  iic_guardian_line: pinteger;                              { +0x9A }
  iic_users: integer;                                       { +0x9C }
  iic_wire_count: integer;                                  { +0x9E }
  iic_pbu_acquired: boolean;                                { +0xA0 }
  unused_a2: integer;                                       { +0xA2 }
  iic_send_spacing: time_$clock_t := [high := 0, low := 250];
                                                            { +0xA4 }
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if iic_driver %then
  iic_$exists;
  iic_$init;
  call_guardian;
  iic_$acquire;
  iic_$net_start;
  iic_$release;
  iic_$$release;
  iic_$send;
  iic_$receive;
  iic_$receive_check;
  iic_$statistics;
  iic_$int_statistics;
  iic_$self_test;
  iic_$proc2_cleanup;
  send_packet;
  interrupter;
  iic_$int;
  guardian_process;
  iic_$sendp;
  iic_$open_os;
  iic_$close_os;
  iic_$send_os;
%else
  iic_$init;
  iic_$acquire;
  iic_$release;
  iic_$statistics;
  iic_$self_test;
  iic_$send;
  iic_$exists;
  iic_$receive;
  iic_$receive_check;
%endif

%if iic_driver %then
{ The module-local routines of IIC_AQWRD_PROC called before their
  bodies. }
{ body: iic/command.pas }
procedure iic_command(line: pinteger; cmd: integer; out status: status_$t);
  forward; internal;
{ body: iic/map_iova.pas }
procedure iic_map_iova(pa: integer32; iova: integer32); forward; internal;
{ body: iic/send_link.pas }
procedure iic_send_link(line: pinteger; code: integer;
                        out status: status_$t);
  forward; internal;

{ ---- WIRED_PROC ---- }
%include 'iic/exists.pas';                  { IIC_$EXISTS }

{ ---- OS_INIT_PROC ---- }
%include 'iic/init.pas';                    { IIC_$INIT }

{ ---- .TEXT ---- }
%include 'iic/wire_driver.pas';             { iic_wire_driver }
%include 'iic/unwire_driver.pas';           { iic_unwire_driver }
%include 'iic/release_pbu.pas';             { iic_release_pbu }
%include 'iic/setup_pbu.pas';               { iic_setup_pbu }
%include 'iic/stop.pas';                    { iic_stop }
%include 'iic/start.pas';                   { iic_start }
%include 'iic/call_guardian.pas';           { CALL_GUARDIAN }
%include 'iic/do_acquire.pas';              { iic_do_acquire }
%include 'iic/acquire.pas';                 { IIC_$ACQUIRE }
%include 'iic/net_start.pas';               { IIC_$NET_START }
%include 'iic/release.pas';                 { IIC_$RELEASE }
%include 'iic/release_internal.pas';        { IIC_$$RELEASE }
%include 'iic/send.pas';                    { IIC_$SEND }
%include 'iic/receive.pas';                 { IIC_$RECEIVE }
%include 'iic/receive_check.pas';           { IIC_$RECEIVE_CHECK }
%include 'iic/statistics.pas';              { IIC_$STATISTICS }
%include 'iic/int_statistics.pas';          { IIC_$INT_STATISTICS }
%include 'iic/self_test.pas';               { IIC_$SELF_TEST }
%include 'iic/range_overlaps.pas';          { iic_range_overlaps }

{ ---- PROC2_DELETE_PRO ---- }
%include 'iic/proc2_cleanup.pas';           { IIC_$PROC2_CLEANUP }

{ ---- IIC_AQWRD_PROC ---- }
%include 'iic/command.pas';                 { iic_command }
%include 'iic/map_iova.pas';                { iic_map_iova }
%include 'iic/send_packet.pas';             { SEND_PACKET }
%include 'iic/send_link.pas';               { iic_send_link }
%include 'iic/interrupter.pas';             { INTERRUPTER }
%include 'iic/int.pas';                     { IIC_$INT }
%include 'iic/guardian_process.pas';        { GUARDIAN_PROCESS }
%include 'iic/sendp.pas';                   { IIC_$SENDP }
%include 'iic/open_internal.pas';           { iic_open_internal }
%include 'iic/open_os.pas';                 { IIC_$OPEN_OS }
%include 'iic/close_os.pas';                { IIC_$CLOSE_OS }
%include 'iic/send_os.pas';                 { IIC_$SEND_OS }
%else
{ ---- .TEXT ---- }
%include 'iic/init.pas';                    { IIC_$INIT          }
%include 'iic/acquire.pas';                 { IIC_$ACQUIRE       }
%include 'iic/release.pas';                 { IIC_$RELEASE       }
%include 'iic/statistics.pas';              { IIC_$STATISTICS    }
%include 'iic/self_test.pas';               { IIC_$SELF_TEST     }
%include 'iic/send.pas';                    { IIC_$SEND          }
%include 'iic/exists.pas';                  { IIC_$EXISTS        }
%include 'iic/receive.pas';                 { IIC_$RECEIVE       }
%include 'iic/receive_check.pas';           { IIC_$RECEIVE_CHECK }
%endif
