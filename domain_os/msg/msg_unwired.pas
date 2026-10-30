{ msg/msg_unwired.pas - the MSG_UNWIRED module, MSG's socket calls: the
  ownership and depth tables, open, allocate and close, receive, send,
  wait and send-and-receive, the eventcount and the address spaces' fork
  and exit.

  Image addresses:
    sau2  0x00E80D84  MSG_UNWIRED data (.DATA, 0x8E4 bytes)

  One compilation unit, `module msg_unwired;': the map's MSG_UNWIRED
  code segments in OS_INIT_PROC (MSG_$INIT), .TEXT (MSG_$GET_MY_NET ..
  MSG_$SHARE_SOCKET), PROC2_CREATE_PRO (MSG_$FORK) and PROC2_DELETE_PRO
  (MSG_$FREE_ASID), each headed with its sections, and its data segment
  in .DATA (2276 bytes).

  MSG_WIRED is msg/msg_wired.pas.

  The data, zero but the template's first 16 bytes:
    +0x000  msg_$send_template  30 bytes, MSG_$SEND's and MSG_$SAR's
    +0x01E  unused_1e           2 bytes, a stand-in (TODO below)
    +0x020  msg_$depth          224 * 2 bytes from socket 1, never read
    +0x1E0  msg_$ownership      224 * 8 bytes from socket 1
    +0x8E0  msg_$open_count     2 bytes, then 2 bytes of rounding

  The routines live in one fragment file each (msg/<name>.pas), included
  below in image order; MSG_$RCVI's is msg/rcvi.pas, msg_$$rcv_internal
  lying between it and MSG_$RCV.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/msg/msg_unwired.pas.  Check: tools/pascal_check.sh.
}

{ TODO(pascal) the 2 bytes at +0x1E of the MSG_UNWIRED block

  The template is 30 bytes (it is copied whole as seven longwords and a
  word) and the depth table's socket 1 is at +0x20.  Either the table
  starts at 0, its element 0 at +0x1E (a socket 0 no routine stores,
  MSG_$OPENI refusing it), or it starts at 1 at +0x20 and the two bytes
  are padding: objects of 8 bytes or more at multiples of 8 from the
  block, which the ownership table at +0x1E0 also fits, or a 32-byte
  template type of which MSG copies 30 bytes.  The code is the same; the
  stand-in unused_1e keeps the layout. }

{ TODO(pascal) the 8-byte alignment of MSG's frame objects

  In the SAU2 frames the templates and address records of 30 bytes lie
  at multiples of 8, two bytes below the space their size needs
  (MSG_$SEND's template, MSG_$SAR's address record and template,
  MSG_$RCV's and MSG_$RCV_CONTIG's address records, MSG_$RCV_HW's);
  MSG_$$SEND's 0x40-byte packet record, its 32-byte packet info and its
  16-byte pages fit the same rule (an 8-byte alignment of frame objects
  of 8 bytes or more), not settled; dpc aligns frame objects to 4 at
  most, so msg/rcv.pas, msg/sar.pas and msg/rcv_hw.pas declare 2-byte
  stand-ins where the alignment leaves bytes, and msg/send.pas,
  msg/sendi.pas, msg/rcv_contig.pas and msg/rcv_contigi.pas, whose
  frames dpc lays out otherwise (value parameters' copies first), none. }

module msg_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';
%include 'msg/msg.ins.pas';

{ The module's own variables (ref 3.2), in the order of the block
  (above), and the globals it defines (ref 7.3.4, Method 2), the
  routines in map order. }
var
  msg_$send_template: msg_$template_t :=
    [flags := [], routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long, protocol := 16#8031,
     retry_limit := 16#FFFF, field_0a := 0, field_0c := 16#FFFF];
                                                  { +0x000 }
  unused_1e: integer;                             { +0x01E, stand-in }
  msg_$depth: array[1..msg_max_socket] of integer;
                                                  { +0x020, zero }
  msg_$ownership: array[1..msg_max_socket] of msg_$owner_t;
                                                  { +0x1E0, zero }
  msg_$open_count: integer;                       { +0x8E0, zero }

define
  msg_$init;
  msg_$get_my_net;
  msg_$get_my_node;
  msg_$set_hpipc;
  msg_$open;
  msg_$openi;
  msg_$allocate;
  msg_$allocatei;
  msg_$close;
  msg_$closei;
  msg_$rcv;
  msg_$rcvi;
  msg_$rcv_contig;
  msg_$rcv_contigi;
  msg_$rcv_hw;
  msg_$send;
  msg_$sendi;
  msg_$send_hw;
  msg_$wait;
  msg_$waiti;
  msg_$get_ec;
  msg_$sar;
  msg_$sari;
  msg_$test_for_message;
  msg_$share_socket;
  msg_$fork;
  msg_$free_asid;

{ ---- OS_INIT_PROC ---- }
%include 'msg/init.pas';                    { MSG_$INIT }

{ ---- .TEXT ---- }
%include 'msg/get_my_net.pas';              { MSG_$GET_MY_NET }
%include 'msg/get_my_node.pas';             { MSG_$GET_MY_NODE }
%include 'msg/set_hpipc.pas';               { MSG_$SET_HPIPC }
%include 'msg/open.pas';                    { MSG_$OPEN }
%include 'msg/openi.pas';                   { MSG_$OPENI }
%include 'msg/allocate.pas';                { MSG_$ALLOCATE }
%include 'msg/allocatei.pas';               { MSG_$ALLOCATEI }
%include 'msg/close.pas';                   { MSG_$CLOSE }
%include 'msg/closei.pas';                  { MSG_$CLOSEI }
%include 'msg/rcv.pas';                     { MSG_$RCV }
%include 'msg/rcv_internal.pas';            { msg_$$rcv_internal }
%include 'msg/rcvi.pas';                    { MSG_$RCVI }
%include 'msg/rcv_contig.pas';              { MSG_$RCV_CONTIG }
%include 'msg/rcv_contigi.pas';             { MSG_$RCV_CONTIGI }
%include 'msg/rcv_hw.pas';                  { MSG_$RCV_HW }
%include 'msg/send.pas';                    { MSG_$SEND }
%include 'msg/sendi.pas';                   { MSG_$SENDI }
%include 'msg/send_hw.pas';                 { MSG_$SEND_HW }
%include 'msg/wait.pas';                    { MSG_$WAIT }
%include 'msg/waiti.pas';                   { MSG_$WAITI }
%include 'msg/get_ec.pas';                  { MSG_$GET_EC }
%include 'msg/sar.pas';                     { MSG_$SAR }
%include 'msg/sari.pas';                    { MSG_$SARI }
%include 'msg/test_for_message.pas';        { MSG_$TEST_FOR_MESSAGE }
%include 'msg/share_socket.pas';            { MSG_$SHARE_SOCKET }

{ ---- PROC2_CREATE_PRO ---- }
%include 'msg/fork.pas';                    { MSG_$FORK }

{ ---- PROC2_DELETE_PRO ---- }
%include 'msg/free_asid.pas';               { MSG_$FREE_ASID }
