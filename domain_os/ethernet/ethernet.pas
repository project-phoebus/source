{ ethernet/ethernet.pas - the ETHERNET module, the Ethernet controller
  driver.

  Image addresses:
    sau8  0x03C9FC04  ETHERNET data (ETHER_DATA, 0xE0 bytes)
    sau9  0x3C49F804  ETHERNET data (ETHER_DATA, 0xE0 bytes)

  One compilation unit, one code segment.  Where the driver is
  configured out (the SAU2), the map's ETHERNET code segment in section
  ETHER_PROC (0x10 bytes) holds ETHERNET_$INIT (14 bytes) and the
  compiled module-end filler, and its data segment (ETHER_DATA) is
  empty.

  With the driver (`ethernet_driver', base/config.ins.pas), on the SAU9:
  the driver of the 3C505 adapter (ethernet/ethernet_3c505.ins.pas).  The
  map's ETHERNET code segment in ETHER_PROC (0x4684 bytes: 43 module-
  local routines and two nested ones, ETHERNET_$INIT .. ETHERNET_$RCV1, 22 symbols) and its
  data segment in ETHER_DATA (0xE0 bytes, below); the ETHERNET_ASM
  segment (0x80 bytes, ETHERNET_$$PIO_READ and ETHERNET_$$PIO_WRITE) is
  hand assembly (ethernet/m68k/ethernet_asm.s).  Two more sections hold
  the driver's objects: ETHER_UCB (0x2570 bytes, the two units' records)
  and ETHERNET_$BUFFER (0x1000 bytes), overlay sections declared below.

  Not part of the module: ETHER_PROC_START and ETHER_PROC_END, the zero
  longwords on either side of the code section; with ETHER_DATA_START
  and ETHER_DATA_END they bound the driver's code and its data (the
  driver wires from one to the other; layout marks for the build,
  tools/gen_layout_ld.py).

  The heading names ETHER_PROC and ETHER_DATA: the block's objects are
  module variables, reached through A5.

  The data block (ETHER_DATA), zero except the driver record and the
  receive processes' table:

    +0x000  ethernet_wire_list    the driver's wired pages, 32
    +0x080  ethernet_driver       the NET_IO driver record
    +0x0D0  ethernet_port_array   the units' NET_IO ports
    +0x0D4  ethernet_wire_users   the units that keep the driver wired
    +0x0D6  ethernet_wire_cnt     the driver's wired pages' count
    +0x0D8  ethernet_rcv_proc     addr(ETHERNET_$RCV0),
                                  addr(ETHERNET_$RCV1)

  The routines live in one fragment file each (ethernet/<name>.pas),
  included below in image order (ethernet/README.md has the
  table).

  Check: tools/pascal_check.sh.
}

module ethernet, ether_proc, ether_data;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%if ethernet_driver %then
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'di/di.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'mst/mst.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'wp/wp.ins.pas';
%include 'node/node.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';
%include 'log/log.ins.pas';
%include 'os/os.ins.pas';
%include 'fim/fim.ins.pas';
%include 'network/network.ins.pas';
%endif
%include 'ethernet/ethernet.ins.pas';
%if ethernet_driver %then
%include 'ethernet/ethernet_3c505.ins.pas';

{ The two units' records (the map's ETHER_UCB, a load section with no
  module segment in it, 0x2570 bytes) and the driver's buffer (the map's
  ETHERNET_$BUFFER, 0x1000 bytes): overlay sections (ref 3.14 p. 3-52;
  7.2.4, Method 4). }
var (ether_ucb)
  ether_ucb: array[0..eth_max_unit] of ethernet_$unit_t;
var (ethernet_$buffer)
  ethernet_$buffer: array[0..4095] of char;

{ The module's own variables, in the order of the data block (above). }
var
  ethernet_wire_list: array[1..32] of integer32;    { +0x000 }
  ethernet_driver: ethernet_$driver_t := [
    unknown0 := 2,
    max_data_len := 1024,
    mtu := 1514,
    sendp := addr(ethernet_$send),
    get_stats := addr(ethernet_$get_stats),
    get_stats2 := addr(ethernet_$get_stats2),
    start := addr(ethernet_$start),
    stop := addr(ethernet_$stop),
    detach := addr(ethernet_$load),
    proc2_cleanup := addr(ethernet_$proc2_cleanup),
    ioctl := addr(ethernet_$ioctl),
    svc_open := addr(ethernet_$svc_open),
    svc_close := addr(ethernet_$svc_close),
    svc_ioctl := addr(ethernet_$svc_ioctl),
    svc_write := addr(ethernet_$svc_write),
    svc_read := addr(ethernet_$svc_read),
    open_os := addr(ethernet_$open_os),
    close_os := addr(ethernet_$close_os),
    send_os := addr(ethernet_$send_os)];           { +0x080 }
  ethernet_port_array: array[0..eth_max_unit] of integer;   { +0x0D0 }
  ethernet_wire_users: integer;                     { +0x0D4 }
  ethernet_wire_cnt: integer;                       { +0x0D6 }
  ethernet_rcv_proc: array[0..eth_max_unit] of univ_ptr :=
    [addr(ethernet_$rcv0), addr(ethernet_$rcv1)];   { +0x0D8 }
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  ethernet_$init;
%if ethernet_driver %then
  ethernet_$start;
  ethernet_$stop;
  ethernet_$load;
  ethernet_$send;
  ethernet_$get_stats;
  ethernet_$get_stats2;
  ethernet_$ioctl;
  ethernet_$svc_open;
  ethernet_$svc_close;
  ethernet_$svc_read;
  ethernet_$svc_write;
  ethernet_$svc_ioctl;
  ethernet_$proc2_cleanup;
  ethernet_$open_os;
  ethernet_$close_os;
  ethernet_$send_os;
  ethernet_$int_deferred;
  ethernet_$interrupt;
  ethernet_$rcv0;
  ethernet_$rcv1;
%endif

{ ---- ETHER_PROC ---- }
%if ethernet_driver %then
%include 'ethernet/swap32.pas';             { ethernet_swap32 }
%include 'ethernet/check_status.pas';       { ethernet_check_status }
%include 'ethernet/wire_driver.pas';        { ethernet_wire_driver }
%include 'ethernet/unwire_driver.pas';      { ethernet_unwire_driver }
%include 'ethernet/probe.pas';              { ethernet_probe }
%include 'ethernet/reset.pas';              { ethernet_reset }
%include 'ethernet/get_pcb.pas';            { ethernet_get_pcb }
%include 'ethernet/send_pcb.pas';           { ethernet_send_pcb }
%include 'ethernet/start_cmd.pas';          { ethernet_start_cmd }
%include 'ethernet/wait_cmd.pas';           { ethernet_wait_cmd }
%include 'ethernet/do_cmd.pas';             { ethernet_do_cmd }
%include 'ethernet/get_rcv_bufs.pas';       { ethernet_get_rcv_bufs }
%include 'ethernet/start_rcv.pas';          { ethernet_start_rcv }
%include 'ethernet/configure.pas';          { ethernet_configure }
%include 'ethernet/do_cmd_polled.pas';      { ethernet_do_cmd_polled }
%include 'ethernet/setup.pas';              { ethernet_setup }
%include 'ethernet/start_unit.pas';         { ethernet_start_unit }
%include 'ethernet/stop_rcv.pas';           { ethernet_stop_rcv }
%include 'ethernet/download.pas';           { ethernet_download }
%include 'ethernet/execute.pas';            { ethernet_execute }
%include 'ethernet/transmit.pas';           { ethernet_transmit }
%include 'ethernet/rcv_packet.pas';         { drain, ethernet_rcv_packet }
%include 'ethernet/arp_request.pas';        { ethernet_arp_request }
%include 'ethernet/arp_reply.pas';          { ethernet_arp_reply }
%include 'ethernet/arp_find.pas';           { ethernet_arp_find }
%include 'ethernet/arp_input.pas';          { ethernet_arp_input }
%include 'ethernet/arp_resolve.pas';        { ethernet_arp_resolve }
%include 'ethernet/range_overlaps.pas';     { ethernet_range_overlaps }
%include 'ethernet/find_adjacent.pas';      { ethernet_find_adjacent }
%include 'ethernet/find_range.pas';         { ethernet_find_range }
%include 'ethernet/rtn_bufs.pas';           { ethernet_rtn_bufs }
%include 'ethernet/demux.pas';              { ethernet_demux }
%include 'ethernet/mcast_listed.pas';       { ethernet_mcast_listed }
%include 'ethernet/mcast_add.pas';          { ethernet_mcast_add }
%include 'ethernet/load_mcast.pas';         { ethernet_load_mcast }
%include 'ethernet/read_stats.pas';         { ethernet_read_stats }
%endif
%include 'ethernet/init.pas';               { ETHERNET_$INIT }
%if ethernet_driver %then
%include 'ethernet/start.pas';              { ETHERNET_$START }
%include 'ethernet/stop.pas';               { ETHERNET_$STOP }
%include 'ethernet/load.pas';               { ETHERNET_$LOAD }
%include 'ethernet/send.pas';               { ETHERNET_$SEND }
%include 'ethernet/get_stats.pas';          { ETHERNET_$GET_STATS }
%include 'ethernet/get_stats2.pas';         { ETHERNET_$GET_STATS2 }
%include 'ethernet/ioctl.pas';              { ETHERNET_$IOCTL }
%include 'ethernet/open.pas';               { ethernet_open }
%include 'ethernet/svc_open.pas';           { ETHERNET_$SVC_OPEN }
%include 'ethernet/svc_close.pas';          { ETHERNET_$SVC_CLOSE }
%include 'ethernet/copy_to_user.pas';       { ethernet_copy_to_user }
%include 'ethernet/svc_read.pas';           { ETHERNET_$SVC_READ }
%include 'ethernet/copy_data.pas';          { ethernet_copy_data }
%include 'ethernet/svc_write.pas';          { ETHERNET_$SVC_WRITE }
%include 'ethernet/svc_ioctl.pas';          { set_station, ETHERNET_$SVC_IOCTL }
%include 'ethernet/proc2_cleanup.pas';      { ETHERNET_$PROC2_CLEANUP }
%include 'ethernet/open_os.pas';            { ETHERNET_$OPEN_OS }
%include 'ethernet/close_os.pas';           { ETHERNET_$CLOSE_OS }
%include 'ethernet/send_os.pas';            { ETHERNET_$SEND_OS }
%include 'ethernet/start_rcv_cond.pas';     { ethernet_start_rcv_cond }
%include 'ethernet/arp_input_cond.pas';     { ethernet_arp_input_cond }
%include 'ethernet/demux_int.pas';          { ethernet_demux_int }
%include 'ethernet/get_rcv_bufs_cond.pas';  { ethernet_get_rcv_bufs_cond }
%include 'ethernet/int_deferred.pas';       { ETHERNET_$INT_DEFERRED }
%include 'ethernet/interrupt.pas';          { ETHERNET_$INTERRUPT }
%include 'ethernet/rcv_process.pas';        { ethernet_rcv_process }
%include 'ethernet/rcv0.pas';               { ETHERNET_$RCV0 }
%include 'ethernet/rcv1.pas';               { ETHERNET_$RCV1 }
%endif
