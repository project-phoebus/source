{ ring/ring.ins.pas - RING_ routine headings, for the Domain Pascal tree.

  Include base/base.ins.pas before it.
}

{ RING_INTERRUPT - the ring's first-level interrupt routine. }
procedure ring_interrupt; extern;

{ RING_$SEND_NULL - an empty procedure.  Its one caller, the SAU4's
  WIN_$DO_IO, passes a unit word by address. }
procedure ring_$send_null(in unit: integer); extern;

var
  { RING_$OVERFLOW_OVERFLOW and RING_$FILE_OVERFLOW (map symbols inside
    NET_IO's block, WIRED_DATA): counters APP_$DEMUX increments. }
  ring_$overflow_overflow: extern pinteger;
  ring_$file_overflow: extern pinteger;

  { RING_$DELIVERY_FAILED (map symbol inside NET_IO's block, the third
    counter): NET_IO's delivery routine counts an undelivered packet
    (NET_IO's block defines all three). }
  ring_$delivery_failed: extern pinteger;

{ ---- The RING statuses, the RING_WIRED block's objects,
  RING_$NETWORK_UID and the RING block's map-named counters.  These need
  base/base.ins.pas only: this file's users include it after base, ec,
  ml (app/app.pas) or base, ec, time, pkt, route (net_io/net_io.pas),
  and before ml or net_io.  The driver's own records and the headings of
  the RING_ routines, which need ec, ml, io, pkt, route, sock, net_io
  and mac_os, are in ring/ring_driver.ins.pas. ---- }

const
  { The ring driver's statuses, subsystem 0x31 (stcode.db.10.2, "OS /
    Ring": the texts). }
  status_$ring_not_implemented = 16#00310001;          { feature is not implemented }
  status_$ring_invalid_unit_num = 16#00310002;         { invalid controller unit number }
  status_$ring_illegal_header_length = 16#00310003;    { illegal header length }
  status_$ring_invalid_data_length = 16#00310004;      { illegal data length }
  status_$ring_transmit_failed = 16#00310005;          { transmit operation failed }
  status_$ring_no_packet_to_receive = 16#00310006;     { no packet available to receive }
  status_$ring_pkt_type_in_use = 16#00310007;          { packet type is already in use }
  status_$ring_no_channels = 16#00310008;              { no channels are available }
  status_$ring_invalid_svc_packet_type = 16#00310009;  { invalid svc packet type }
  status_$ring_channel_not_open = 16#0031000A;         { channel is not open }
  status_$ring_device_offline = 16#0031000B;           { device is off-line }
  status_$ring_device_already_online = 16#0031000C;    { device is already on-line }
  status_$ring_internal_driver_error = 16#0031000D;    { internal driver error }
  status_$ring_controller_hardware_error = 16#0031000E;  { controller hardware error }
  status_$ring_pkt_type_not_in_use = 16#0031000F;      { packet type is not already in use }
  status_$ring_driver_version_mismatch = 16#00310010;  { driver version mismatch }
  status_$ring_invalid_stats_block = 16#00310011;      { invalid statistics block }
  status_$ring_illegal_dest_address = 16#00310012;     { illegal destination address }

type
  { A unit's statistics, 0x3C bytes (Apollo's netmain labels), RING_$DATA's
    elements from 0.  The longwords at 0x2 and at 0x6 are where the word
    rules put them.  The four bytes from 0x34 are booleans, each followed
    by a byte no instruction addresses.  last_success is true after a
    send the ring did not take (ring/README.md, Open items, on
    the name).  unused_00 is 1 in the image. }
  ring_$stats_t = record
    unused_00: integer;                   { 0x00 }
    xmit_call: integer32;                 { 0x02 }
    xmitcnt: integer32;                   { 0x06 }
    xmit_nack: pinteger;                  { 0x0A }
    xmit_wack: pinteger;                  { 0x0C }
    xmit_orun: pinteger;                  { 0x0E }
    xmit_apar: pinteger;                  { 0x10 }
    xmit_bus: pinteger;                   { 0x12 }
    xmit_nortn: pinteger;                 { 0x14 }
    xmit_modem: pinteger;                 { 0x16 }
    xmit_error: pinteger;                 { 0x18 }
    xmit_tim: pinteger;                   { 0x1A }
    rcvcnt: integer32;                    { 0x1C }
    rcveor: pinteger;                     { 0x20 }
    rcvcrc: pinteger;                     { 0x22 }
    rcvtim: pinteger;                     { 0x24 }
    rcvbus: pinteger;                     { 0x26 }
    rcvmodem: pinteger;                   { 0x28 }
    rcvpkt: pinteger;                     { 0x2A }
    rcvovr: pinteger;                     { 0x2C }
    rcvapar: pinteger;                    { 0x2E }
    rcvxerr: pinteger;                    { 0x30 }
    rcvhcsum: pinteger;                   { 0x32 }
    last_success: boolean;                { 0x34 }
    unused_35: char;                      { 0x35 }
    congestion_flag: boolean;             { 0x36 }
    unused_37: char;                      { 0x37 }
    biphase_flag: boolean;                { 0x38 }
    unused_39: char;                      { 0x39 }
    retry_pending: boolean;               { 0x3A }
    unused_3b: char;                      { 0x3B }
  end;

  { The software diagnostic's receive counters, 0x1E bytes: the ten words
    from 0x06 are those of ring_$stats_t from 0x20.  No RING routine
    names the words at 0x00..0x05 and at 0x1A..0x1D (the unused_ fields;
    the first is 1 in the image). }
  ring_$swdiag_t = record
    unused_00: integer;                   { 0x00 }
    unused_02: integer;                   { 0x02 }
    unused_04: integer;                   { 0x04 }
    rcveor: pinteger;                     { 0x06 }
    rcvcrc: pinteger;                     { 0x08 }
    rcvtim: pinteger;                     { 0x0A }
    rcvbus: pinteger;                     { 0x0C }
    rcvmodem: pinteger;                   { 0x0E }
    rcvpkt: pinteger;                     { 0x10 }
    rcvovr: pinteger;                     { 0x12 }
    rcvapar: pinteger;                    { 0x14 }
    rcvxerr: pinteger;                    { 0x16 }
    rcvhcsum: pinteger;                   { 0x18 }
    unused_1a: array[1..2] of integer;    { 0x1A }
  end;

var
  { The RING_WIRED block (WIRED_DATA), every object a map symbol, defined
    by ring/ring_wired.pas with the image's bytes. }
  ring_$swdiag_nodeid: extern integer32;
  ring_$swdiag_goodrcv_cnt: extern integer32;
  ring_$swdiag_rcvcnt: extern integer32;
  ring_$rcv_biphase: extern pinteger;
  ring_$rcv_esb: extern pinteger;
  ring_$xmit_biphase: extern pinteger;
  ring_$xmit_esb: extern pinteger;
  ring_$paging_overflow: extern pinteger;
  ring_$swdiag_data: extern ring_$swdiag_t;
  ring_$data: extern array[0..1] of ring_$stats_t;

  { RING_$NETWORK_UID (map symbol in UID_LIST's run of the network-type
    UIDs, with NIL_$NETWORK_UID, uid/uid.ins.pas): RING_$INIT copies it
    into the driver record's UID. }
  ring_$network_uid: extern uid_$t;

  { The RING block's map-named counters (RING's RING_DATA segment),
    defined by ring/ring.pas (all zero).  RING_$UNEXPECTED_XMIT_STAT
    takes a transmit status word (ring/ring_driver.ins.pas ring_$csr_t),
    here its integer.  RING_$TMASK_CHG_AND_BUSY_CNT, RING_$SEND_NULL_CNT
    and RING_$CLOBBERED_HDR no RING routine addresses. }
  ring_$set_tmask_chg_cnt: extern integer32;
  ring_$unit_tmask_chg_cnt: extern integer32;
  ring_$tmask_chg_and_busy_cnt: extern integer32;
  ring_$rcv_int_cnt: extern integer32;
%if ring8_controller %then
  { With `ring8_controller': the receive process's restarts of a stopped
    receive, RING_$POST_CNT3 on its own next buffer, RING_$POST_CNT1 and
    _CNT2 on the buffer after the controller's last, _CNT1 when that is
    the one before the process's next; and RING_$RCV_EVCNTR, which no
    RING routine addresses. }
  ring_$post_cnt3: extern pinteger;
  ring_$post_cnt2: extern pinteger;
  ring_$post_cnt1: extern pinteger;
%endif
  ring_$unexpected_xmit_stat: extern pinteger;
  ring_$bad_data_cnt: extern pinteger;
  ring_$wakeup_cnt: extern pinteger;
  ring_$abort_cnt: extern pinteger;
  ring_$busy_on_rcv_int: extern pinteger;
  ring_$send_null_cnt: extern pinteger;
  ring_$clobbered_hdr: extern pinteger;
  ring_$xmit_waited: extern pinteger;
%if ring8_controller %then
  ring_$rcv_evcntr: extern pinteger;
%endif

{ RING_$SVC_IOCTL's commands (its `case args.cmd of', entries 1..4).
  No Apollo insert declares them. }
const
  ring_$ioctl_nop = 1;
  ring_$ioctl_add_types = 2;
  ring_$ioctl_remove_types = 3;
  ring_$ioctl_get_stats = 4;
