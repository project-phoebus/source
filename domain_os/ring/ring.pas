{ ring/ring.pas - the RING module: the token-ring driver.

  Image addresses:
    sau2  0x00E35028  RING data (OS_INIT_DATA, 4 bytes)
    sau2  0x00E86400  RING data (RING_DATA, 0x5D0 bytes)
    sau5  0x00E37828  RING data (OS_INIT_DATA, 4 bytes)
    sau5  0x00E8EC00  RING data (RING_DATA, 0x5D0 bytes)
    sau9  0x3C43BC28  RING data (OS_INIT_DATA, 0xB0 bytes)
    sau9  0x3C49EC00  RING data (RING_DATA, 0xAB0 bytes)

  One compilation unit in two code sections and two data sections: the
  map's RING code segments in OS_INIT_PROC (0x1A8 bytes, RING_$GET_ID,
  RING_$INIT) and in RING_PROC (0x2B34 bytes, RING_$INT ..
  RING_$SEND_OS, 24 symbols, between RING_PROC_START and RING_PROC_END).

  Its data segments: OS_INIT_DATA (4 bytes, zero, no object of this
  unit) and RING_DATA (0x5D0 bytes, RING_DATA_START .. RING_DATA_END).

  The RING_WIRED block (WIRED_DATA) is a module of its own
  (ring/ring_wired.pas), RINGLOG_ another (ring/ringlog_.pas),
  RING_INTERRUPT ATBUS_'s (ring/interrupt.pas).

  The heading: the RING_DATA block's objects are module variables, most
  of them map symbols `define'd here, so `module ring, ring_proc,
  ring_data;'.  RING_$GET_ID, RING_$INIT and ring_$init_internal are
  headed `[section(os_init_proc, os_init_data)]', and reach the
  RING_DATA block by its address.

  The data, 0x5D0 bytes (zero but the driver record, the clocks and the
  table of the receive processes):

    +0x000  RING_$CTL                 0x488  the two units
    +0x488  RING_$SCRUB               8      (no reference)
    +0x490  RING_$FROM_ERR            8      (no reference)
    +0x498  ring_$wire_list           0x80   ring_$wire_driver's pages
    +0x518  ring_$driver              0x50   the NET_IO driver record

    +0x568  RING_$FORCE_START         6
    +0x570  ring_$scrub_delay         6      0, 137 (no reference)
    +0x578  ring_$xmit_timeout1       6      0, 1058
    +0x580  ring_$xmit_timeout2       6      0, 683

    +0x588  ring_$wait_interval       6      0, 683 (no reference)
    +0x590  ring_$poll_timeout        6      0, 375
    +0x598  ring_$wait_timeout        6      5, 16#9E22
            (each clock followed by a 2-byte stand-in, the TODO below)

    +0x5A0  ring_$port_array          4      the units' NET_IO ports
    +0x5A4  RING_$SET_TMASK_CHG_CNT .. RING_$RCV_INT_CNT  4 * 4
    +0x5B4  ring_$wire_cnt            2

    +0x5B6  RING_$UNEXPECTED_XMIT_STAT .. RING_$XMIT_WAITED  2 * 8
    +0x5C6  unused_5c6                2      stand-in
    +0x5C8  ring_$rcv_proc            8      addr(RING_$RCV0),
                                             addr(RING_$RCV1)

  The routines live in one fragment file each, included below in image
  order (ring/README.md has the table).  With a controller that
  moves its packets itself (`ring_controller_dma', base/config.ins.pas)
  there is no ring_$clear_dma_channel, and the RING_PROC segment is
  0x29B4 bytes; the blocks are the same.  ring_$receive_packet, called
  before its body, has a `forward' heading below.

  With the controller with buffers of its own (`ring8_controller') the
  OS_INIT_PROC segment is 0x420 bytes and RING_PROC 0x33F0 (RING8_$INT
  in place of RING_$INT, and the module-local routines that drive the
  controller in place of the DMA ones; ring_$set_ccb, which
  ring_$init_internal calls, has a `forward' heading below).
  OS_INIT_DATA holds ring_$init_internal's tables (0xB0 bytes), and
  RING_DATA is 0xAB0 bytes:

    +0x000  RING_$CCB                 0x10   the units' command blocks
    +0x010  RING_$CTL                 0x948  the two units (each with
                                             its receive page, rx_next
                                             1 and rx_stopped)
    +0x958  RING_$SCRUB               8
    +0x960  RING_$FROM_ERR            8
    +0x968  ring_$wire_list           0x80
    +0x9E8  ring_$driver              0x50
    +0xA38  ring_$io_unit             4      IO_$ACQUIRE's units

    +0xA3C  RING_$FORCE_START         6
    +0xA44  ring_$scrub_delay         6      0, 137
    +0xA4C  ring_$xmit_timeout1       6      0, 3106
    +0xA54  ring_$xmit_timeout2       6      0, 2731
    +0xA5C  ring_$wait_interval       6      0, 2731
    +0xA64  ring_$poll_timeout        6      0, 375
    +0xA6C  ring_$wait_timeout        6      5, 16#9E22
            (each clock followed by a 2-byte stand-in)

    +0xA74  ring_$port_array          4
    +0xA78  RING_$SET_TMASK_CHG_CNT .. RING_$RCV_INT_CNT  4 * 4
    +0xA88  RING_$POST_CNT3 .. RING_$POST_CNT1  2 * 3
    +0xA8E  ring_$wire_cnt            2
    +0xA90  RING_$UNEXPECTED_XMIT_STAT .. RING_$XMIT_WAITED  2 * 8
    +0xAA0  ring_$int_acquired        1      the first unit's interrupt
                                             acquired
    +0xAA2  RING_$RCV_EVCNTR          2      (no reference)
    +0xAA4  unused_aa4                4      stand-in
    +0xAA8  ring_$rcv_proc            8

  RING_ASM's hand assembly (RING_$RB_FROM, RING_$RB_TO) follows the
  block in RING_DATA.

  Build: dpc -I domain_os domain_os/ring/ring.pas.  Check:
  tools/pascal_check.sh.
}

{ TODO(pascal) 16 bytes of the RING block no object explains

  The 2 bytes after each of the seven clocks from +0x568 and
  +0x5C6..+0x5C7 before the table of the receive processes: no
  instruction addresses them, and the word rules put the next object
  directly after a 6-byte clock.  Each clock takes 8 bytes as
  time_$clock_t locals do in frames, and the table is a longword's
  place.  The stand-ins hold the places.  With `ring8_controller' the
  same 2 bytes follow each clock from +0xA3C, and the 4 bytes at +0xAA4
  (unused_aa4) before the table are another such place. }

{ TODO(pascal) frames of the RING routines not checked against dpc's layout

  The fragments' SAU2 frames are accounted from the image by hand;
  several leave 4 to 12 bytes no object explains, and the module-local
  routines that load A5 may reserve differently.  dpc's --dump-locals
  has not been compared routine by routine; stand-ins are added only
  where the fragment says so (RING_$INIT's unused_18 and unused_1c). }

module ring, ring_proc, ring_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'io/io.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'fim/fim.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'parity/parity.ins.pas';
%include 'cal/cal.ins.pas';
%include 'dma/dma.ins.pas';
%include 'ring/ring.ins.pas';
%include 'ring/ringlog.ins.pas';
%include 'ring/ring_driver.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
%if ring8_controller %then
define
  ring_$ccb;                              { +0x000, zero }
  ring_$ctl := [
    [rcv_page := addr(ring_rcv_page), rx_next := 1, rx_stopped := true],
    [rcv_page := addr(ring2_rcv_page), rx_next := 1,
     rx_stopped := true]];                { +0x010 }
  ring_$scrub;                            { +0x958, zero }
  ring_$from_err;                         { +0x960, zero }
%else
define
  ring_$ctl;                              { +0x000, zero }
  ring_$scrub;                            { +0x488, zero }
  ring_$from_err;                         { +0x490, zero }
%endif

var
  ring_$wire_list: array[0..31] of integer32;    { +0x498, +0x968, zero }
  ring_$driver: ring_$driver_t := [
    unknown0 := 2,
    max_data_len := 1024,
    flags := chr(3),
    sendp := addr(ring_$sendp),
    get_stats := addr(ring_$get_stats),
    get_stats2 := addr(ring_$get_stats),
    start := addr(ring_$start),
    stop := addr(ring_$stop),
    proc2_cleanup := addr(ring_$proc2_cleanup),
    ioctl := addr(ring_$ioctl),
    svc_open := addr(ring_$svc_open),
    svc_close := addr(ring_$svc_close),
    svc_ioctl := addr(ring_$svc_ioctl),
    svc_write := addr(ring_$svc_write),
    svc_read := addr(ring_$svc_read),
    open_os := addr(ring_$open_os),
    close_os := addr(ring_$close_os),
    send_os := addr(ring_$send_os)];               { +0x518, +0x9E8 }
%if ring8_controller %then
  ring_$io_unit: array[0..1] of io_$unit_num_t;  { +0xA38, zero }
%endif

define
  ring_$force_start;                      { +0x568, +0xA3C, zero }

var
  unused_56e: integer;                    { +0x56E, +0xA42, stand-in }
  ring_$scrub_delay: time_$clock_t := [high := 0, low := 137];
                                          { +0x570, +0xA44 }
  unused_576: integer;                    { +0x576, +0xA4A, stand-in }
%if ring8_controller %then
  ring_$xmit_timeout1: time_$clock_t := [high := 0, low := 3106];
                                          { +0xA4C }
%else
  ring_$xmit_timeout1: time_$clock_t := [high := 0, low := 1058];
                                          { +0x578 }
%endif
  unused_57e: integer;                    { +0x57E, +0xA52, stand-in }
%if ring8_controller %then
  ring_$xmit_timeout2: time_$clock_t := [high := 0, low := 2731];
                                          { +0xA54 }
  unused_586: integer;                    { +0xA5A, stand-in }
  ring_$wait_interval: time_$clock_t := [high := 0, low := 2731];
                                          { +0xA5C }
%else
  ring_$xmit_timeout2: time_$clock_t := [high := 0, low := 683];
                                          { +0x580 }
  unused_586: integer;                    { +0x586, stand-in }
  ring_$wait_interval: time_$clock_t := [high := 0, low := 683];
                                          { +0x588 }
%endif
  unused_58e: integer;                    { +0x58E, +0xA62, stand-in }
  ring_$poll_timeout: time_$clock_t := [high := 0, low := 375];
                                          { +0x590, +0xA64 }
  unused_596: integer;                    { +0x596, +0xA6A, stand-in }
  ring_$wait_timeout: time_$clock_t := [high := 5, low := 16#9E22];
                                          { +0x598, +0xA6C }
  unused_59e: integer;                    { +0x59E, +0xA72, stand-in }
  ring_$port_array: array[0..1] of integer;      { +0x5A0, +0xA74, zero }

define
  ring_$set_tmask_chg_cnt;                { +0x5A4, +0xA78, zero }
  ring_$unit_tmask_chg_cnt;               { +0x5A8, +0xA7C, zero }
  ring_$tmask_chg_and_busy_cnt;           { +0x5AC, +0xA80, zero }
  ring_$rcv_int_cnt;                      { +0x5B0, +0xA84, zero }
%if ring8_controller %then
  ring_$post_cnt3;                        { +0xA88, zero }
  ring_$post_cnt2;                        { +0xA8A, zero }
  ring_$post_cnt1;                        { +0xA8C, zero }
%endif

var
  ring_$wire_cnt: integer;                { +0x5B4, +0xA8E, zero }

define
  ring_$unexpected_xmit_stat;             { +0x5B6, +0xA90, zero }
  ring_$bad_data_cnt;                     { +0x5B8, +0xA92, zero }
  ring_$wakeup_cnt;                       { +0x5BA, +0xA94, zero }
  ring_$abort_cnt;                        { +0x5BC, +0xA96, zero }
  ring_$busy_on_rcv_int;                  { +0x5BE, +0xA98, zero }
  ring_$send_null_cnt;                    { +0x5C0, +0xA9A, zero }
  ring_$clobbered_hdr;                    { +0x5C2, +0xA9C, zero }
  ring_$xmit_waited;                      { +0x5C4, +0xA9E, zero }
%if ring8_controller %then

var
  ring_$int_acquired: boolean;            { +0xAA0, zero }

define
  ring_$rcv_evcntr;                       { +0xAA2, zero }

var
  unused_aa4: integer32;                  { +0xAA4, stand-in }
%else

var
  unused_5c6: integer;                    { +0x5C6, stand-in }
%endif
  ring_$rcv_proc: array[0..1] of univ_ptr := [addr(ring_$rcv0),
                                              addr(ring_$rcv1)];
                                          { +0x5C8, +0xAA8 }

define
  ring_$get_id;
  ring_$init;
%if ring8_controller %then
  ring8_$int;
%else
  ring_$int;
%endif
  ring_$send_null;
  ring_$sendp;
  ring_$poll_sticky_bpherr;
  hdr_chksum;
  ring_$rcv0;
  ring_$rcv1;
  ring_$start;
  ring_$kick_driver;
  ring_$set_tmask;
  ring_$get_stats;
  ring_$stop;
  ring_$proc2_cleanup;
  ring_$ioctl;
  ring_$svc_open;
  ring_$svc_close;
  ring_$svc_write;
  ring_$svc_read;
  ring_$svc_ioctl;
  ring_$open_os;
  ring_$close_os;
  ring_$send_os;

{ The module-local routine called before its body (RING_$RCV_FROM_UNIT_
  PRIV calls it; the body comes later). }
{ body: ring/receive_packet.pas }
procedure ring_$receive_packet(unit: integer; var hdr_va: integer32;
                               var data_pa: integer32;
                               var hdr_len: pinteger;
                               var data_len: pinteger);
  forward; internal;
%if ring8_controller %then

{ The module-local routine ring_$init_internal calls before its body. }
{ body: ring/set_ccb.pas }
function ring_$set_ccb(unit: integer; locked: boolean): integer32;
  forward; internal;
%endif

{ ---- OS_INIT_PROC ---- }
%include 'ring/get_id.pas';                 { RING_$GET_ID }
%include 'ring/init_internal.pas';          { ring_$init_internal }
%include 'ring/init.pas';                   { RING_$INIT }

{ ---- RING_PROC ---- }
%if ring8_controller %then
%include 'ring/set_timer.pas';              { ring_$set_timer }
%include 'ring/read_timer.pas';             { ring_$read_timer }
%include 'ring/set_rx_buffer.pas';          { ring_$set_rx_buffer }
%include 'ring/set_ccb.pas';                { ring_$set_ccb }
%include 'ring/process_rx_packet.pas';      { ring_$process_rx_packet }
%include 'ring/ring8_int.pas';              { ring8_$unit_int,
                                              ring8_$start_rx,
                                              RING8_$INT }
%include 'ring/setup_tx.pas';               { ring_$setup_tx }
%include 'ring/copy_rx.pas';                { ring_$copy_rx }
%else
%include 'ring/process_rx_packet.pas';      { ring_$process_rx_packet }
%include 'ring/int.pas';                    { RING_$INT }
%include 'ring/clear_dma_channel.pas';      { ring_$clear_dma_channel }
%include 'ring/setup_tx_dma.pas';           { ring_$setup_tx_dma }
%include 'ring/setup_rx_dma.pas';           { ring_$setup_rx_dma }
%endif
%include 'ring/send_null.pas';              { RING_$SEND_NULL }
%include 'ring/sendp.pas';                  { RING_$SENDP }
%include 'ring/rcv_from_unit_priv.pas';     { ring_$rearm_rx (with
                                              `ring8_controller'),
                                              ring_$validate_receive,
                                              ring_$rcv_from_unit_priv }
%include 'ring/poll_sticky_bpherr.pas';     { RING_$POLL_STICKY_BPHERR }
%include 'ring/hdr_chksum.pas';             { HDR_CHKSUM }
%include 'ring/find_pkt_type.pas';          { ring_$find_pkt_type }
%include 'ring/pkt_type_overlaps.pas';      { ring_$pkt_type_overlaps }
%include 'ring/find_adjacent_pkt_type.pas'; { ring_$find_adjacent_pkt_type }
%include 'ring/find_overlapping_pkt_type.pas';
                                            { ring_$find_overlapping_pkt_
                                              type }
%include 'ring/receive_packet.pas';         { ring_$discard_packet,
                                              ring_$receive_packet }
%include 'ring/rcv0.pas';                   { RING_$RCV0 }
%include 'ring/rcv1.pas';                   { RING_$RCV1 }
%include 'ring/wire_driver.pas';            { ring_$wire_driver }
%include 'ring/do_start.pas';               { ring_$do_start }
%include 'ring/set_hw_mask.pas';            { ring_$set_hw_mask }
%include 'ring/start.pas';                  { RING_$START }
%include 'ring/kick_driver.pas';            { RING_$KICK_DRIVER }
%include 'ring/set_tmask.pas';              { RING_$SET_TMASK }
%include 'ring/get_stats.pas';              { RING_$GET_STATS }
%include 'ring/stop.pas';                   { RING_$STOP }
%include 'ring/proc2_cleanup.pas';          { RING_$PROC2_CLEANUP }
%include 'ring/ioctl.pas';                  { RING_$IOCTL }
%include 'ring/open_internal.pas';          { ring_$open_internal }
%include 'ring/svc_open.pas';               { RING_$SVC_OPEN }
%include 'ring/svc_close.pas';              { RING_$SVC_CLOSE }
%include 'ring/copy_data.pas';              { ring_$copy_data }
%include 'ring/svc_write.pas';              { RING_$SVC_WRITE }
%include 'ring/copy_to_user.pas';           { ring_$copy_to_user }
%include 'ring/svc_read.pas';               { RING_$SVC_READ }
%include 'ring/svc_ioctl.pas';              { RING_$SVC_IOCTL }
%include 'ring/open_os.pas';                { RING_$OPEN_OS }
%include 'ring/close_os.pas';               { RING_$CLOSE_OS }
%include 'ring/send_os.pas';                { RING_$SEND_OS }
