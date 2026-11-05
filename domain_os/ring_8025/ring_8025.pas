{ ring_8025/ring_8025.pas - the RING_8025 module, the IEEE 802.5
  token-ring driver.

  Image addresses:
    sau7  0x3C4B3804  RING_8025 data (RING8025_DATA, 0x164 bytes)
    sau8  0x03CA2804  RING_8025 data (RING8025_DATA, 0x164 bytes)
    sau9  0x3C4A2404  RING_8025 data (RING8025_DATA, 0x168 bytes)

  One compilation unit, one code segment: the map's RING_8025 code
  segment in RING8025_PROC (0x4814 bytes on the SAU9, 0x471C on the
  SAU8, 0x49A4 on the SAU7: module-local routines and the 21 map routines
  RING_8025_$NULLSAP_HELPER .. RING_8025_$RCV1), and its data segment in RING8025_DATA (0x168
  bytes, below).  Two more sections hold the driver's objects:
  RING8025_UCB (0x868 bytes, 0x870 on the SAU7, the two units' records) and
  RING8025_$AUX_DA (0x8000 bytes, the units' receive and transmit
  areas), overlay sections declared below.

  With the part ring_8025_driver (base/config.ins.pas): only the SAU7,
  SAU8 and SAU9 maps have RING_8025.  Elsewhere the module is empty.

  Not part of the module: RING8025_PROC_ST and RING8025_PROC_EN, the
  zero longwords on either side of the code section; with
  RING8025_DATA_ST and RING8025_DATA_EN they bound the driver's code and
  its data (the driver wires from one to the other; layout marks for
  the build, tools/gen_layout_ld.py).

  The heading names RING8025_PROC and RING8025_DATA: the block's objects
  are module variables, reached through A5.

  The data block (RING8025_DATA), zero except the frame-size table and
  the driver record:

    +0x000  ring_8025_lf_size      the routing field's largest-frame
                                   codes' sizes, 8 words
    +0x010  ring_8025_wire_list    the driver's wired pages, 64
    +0x110  ring_8025_driver       the NET_IO driver record
    +0x160  ring_8025_map_pmape    the map page's page table entry
    +0x164  ring_8025_wire_users   the units that keep the driver wired
    +0x166  ring_8025_wire_cnt     the driver's wired pages' count

  With `ring_8025_dma_channel' (base/config.ins.pas) the block has no
  ring_8025_map_pmape (0x164 bytes, the two counts from +0x160), and the
  auxiliary area no map page (0x7C00 bytes).

  The routines live in one fragment file each (ring_8025/<name>.pas),
  included below in image order (ring_8025/README.md has the table).

  Check: tools/pascal_check.sh.
}

module ring_8025, ring8025_proc, ring8025_data;

%include 'base/base.ins.pas';
%if ring_8025_driver %then
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'io/io.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'os/os.ins.pas';
%include 'fim/fim.ins.pas';
%include 'network/network.ins.pas';
%if ring_8025_dma_channel %then
%include 'dma/dma.ins.pas';
%endif
%if ring_8025_iomap %then
%include 'iomap/iomap.ins.pas';
%endif
%include 'ring_8025/ring_8025.ins.pas';

{ The two units' records (the map's RING8025_UCB, a load section with
  no module segment in it, 0x868 bytes, 0x870 with `ring_8025_iomap') and the auxiliary area (the
  map's RING8025_$AUX_DA, 0x8000 bytes): overlay sections (ref 3.14
  p. 3-52; 7.2.4, Method 4). }
var (ring8025_ucb)
  ring8025_ucb: array[0..r8025_max_unit] of ring_8025_$unit_t;
var (ring8025_$aux_da)
  ring8025_$aux_da: ring_8025_$aux_t;

{ The module's own variables, in the order of the data block (above). }
var
  ring_8025_lf_size: array[0..7] of integer := [
    516, 1500, 2052, 4472, 8191, 8191, 11407, 17800];   { +0x000 }
  ring_8025_wire_list: array[1..r8025_wire_max] of integer32;  { +0x010 }
  ring_8025_driver: ring_8025_$driver_t := [
    unknown0 := 2,
    max_data_len := 1024,
    mtu := 4504,
    sendp := addr(ring_8025_$send),
    get_stats := addr(ring_8025_$get_stats),
    get_stats2 := addr(ring_8025_$get_stats2),
    start := addr(ring_8025_$start),
    stop := addr(ring_8025_$stop),
    detach := addr(ring_8025_$load),
    proc2_cleanup := addr(ring_8025_$proc2_cleanup),
    ioctl := addr(ring_8025_$ioctl),
    svc_open := addr(ring_8025_$svc_open),
    svc_close := addr(ring_8025_$svc_close),
    svc_ioctl := addr(ring_8025_$svc_ioctl),
    svc_write := addr(ring_8025_$svc_write),
    svc_read := addr(ring_8025_$svc_read),
    open_os := addr(ring_8025_$open_os),
    close_os := addr(ring_8025_$close_os),
    send_os := addr(ring_8025_$send_os)];           { +0x110 }
%if not ring_8025_dma_channel %then
  ring_8025_map_pmape: univ_ptr;                    { +0x160 }
%endif
  ring_8025_wire_users: integer;                    { +0x164 }
  ring_8025_wire_cnt: integer;                      { +0x166 }

{ ---- RING8025_PROC ---- }
%include 'ring_8025/swap16.pas';           { ring_8025_swap16 }
%include 'ring_8025/wait.pas';             { ring_8025_wait }
%include 'ring_8025/check_status.pas';     { ring_8025_check_status }
%include 'ring_8025/wire_driver.pas';      { ring_8025_wire_driver }
%include 'ring_8025/unwire_driver.pas';    { ring_8025_unwire_driver }
%if ring_8025_iomap %then
%include 'ring_8025/map_pa.pas';           { ring_8025_map_pa }
%endif
%include 'ring_8025/vtop.pas';             { ring_8025_vtop }
%include 'ring_8025/probe.pas';            { ring_8025_probe }
%include 'ring_8025/reset.pas';            { ring_8025_reset }
%include 'ring_8025/initialize.pas';       { ring_8025_initialize }
%include 'ring_8025/scb_cmd.pas';          { ring_8025_scb_cmd }
%include 'ring_8025/scb_cmd_addr.pas';     { ring_8025_scb_cmd_addr }
%include 'ring_8025/wait_scb.pas';         { ring_8025_wait_scb }
%include 'ring_8025/open.pas';             { ring_8025_open }
%include 'ring_8025/close.pas';            { ring_8025_close }
%include 'ring_8025/start_xmit.pas';       { ring_8025_start_xmit }
%include 'ring_8025/start_rcv.pas';        { ring_8025_start_rcv }
%include 'ring_8025/xmit_halt.pas';        { ring_8025_xmit_halt }
%include 'ring_8025/start_unit.pas';       { ring_8025_start_unit }
%include 'ring_8025/stop_rcv.pas';         { ring_8025_stop_rcv }
%include 'ring_8025/transmit.pas';         { ring_8025_transmit }
%include 'ring_8025/find_type.pas';        { ring_8025_find_type }
%include 'ring_8025/range_overlaps.pas';   { ring_8025_range_overlaps }
%include 'ring_8025/find_adjacent.pas';    { ring_8025_find_adjacent }
%include 'ring_8025/find_range.pas';       { ring_8025_find_range }
%include 'ring_8025/send_xid.pas';         { ring_8025_send_xid }
%include 'ring_8025/learn_route.pas';      { ring_8025_learn_route }
%include 'ring_8025/learn_local.pas';      { ring_8025_learn_local }
%include 'ring_8025/find_route.pas';       { ring_8025_find_route }
%include 'ring_8025/nullsap_helper.pas';   { RING_8025_$NULLSAP_HELPER }
%include 'ring_8025/queue_nullsap.pas';    { ring_8025_queue_nullsap }
%include 'ring_8025/receive_frame.pas';    { ring_8025_receive_frame }
%include 'ring_8025/close_socket.pas';     { ring_8025_close_socket }
%include 'ring_8025/read_stats.pas';       { ring_8025_read_stats }
%include 'ring_8025/init.pas';             { RING_8025_$INIT }
%include 'ring_8025/start.pas';            { RING_8025_$START }
%include 'ring_8025/stop.pas';             { RING_8025_$STOP }
%include 'ring_8025/load.pas';             { RING_8025_$LOAD }
%include 'ring_8025/send.pas';             { RING_8025_$SEND }
%include 'ring_8025/get_stats.pas';        { RING_8025_$GET_STATS }
%include 'ring_8025/get_stats2.pas';       { RING_8025_$GET_STATS2 }
%include 'ring_8025/ioctl.pas';            { RING_8025_$IOCTL }
%include 'ring_8025/open_channel.pas';     { ring_8025_open_channel }
%include 'ring_8025/svc_open.pas';         { RING_8025_$SVC_OPEN }
%include 'ring_8025/svc_close.pas';        { RING_8025_$SVC_CLOSE }
%include 'ring_8025/copy_to_user.pas';     { ring_8025_copy_to_user }
%include 'ring_8025/svc_read.pas';         { RING_8025_$SVC_READ }
%include 'ring_8025/copy_data.pas';        { ring_8025_copy_data }
%include 'ring_8025/svc_write.pas';        { RING_8025_$SVC_WRITE }
%include 'ring_8025/svc_ioctl.pas';        { RING_8025_$SVC_IOCTL }
%include 'ring_8025/proc2_cleanup.pas';    { RING_8025_$PROC2_CLEANUP }
%include 'ring_8025/open_os.pas';          { RING_8025_$OPEN_OS }
%include 'ring_8025/close_os.pas';         { RING_8025_$CLOSE_OS }
%include 'ring_8025/send_os.pas';          { RING_8025_$SEND_OS }
%include 'ring_8025/int.pas';              { RING_8025_$INT }
%include 'ring_8025/rcv_process.pas';      { ring_8025_rcv_process }
%include 'ring_8025/rcv0.pas';             { RING_8025_$RCV0 }
%include 'ring_8025/rcv1.pas';             { RING_8025_$RCV1 }
%endif
