{ msg/msg_wired.pas - the MSG_WIRED module, MSG's wired send path: the
  shared body of the MSG send calls and the bounce page it copies data
  through.

  Image addresses:
    sau2  0x00E242E4  MSG_WIRED data (WIRED_DATA, 0x20 bytes)

  One compilation unit, `module msg_wired, wired_proc, wired_data;': the
  map's MSG_WIRED code segment in WIRED_PROC (MSG_$$SEND,
  msg/send_internal.pas) and its data segment in WIRED_DATA (32 bytes).
  MSG_UNWIRED reaches the block only by its symbols' addresses.

  The data, zero but the claim count:
    +0x00  MSG_$SOCK_LOCK  18 bytes (defined), MSG_UNWIRED's lock
    +0x12  (2 bytes: DPAGE_VA's alignment)

    +0x14  DPAGE_VA        4 bytes (defined), the bounce page's address
    +0x18  DPAGE_PA        4 bytes (defined), its physical address
    +0x1C  DPAGE_LOCK      2 bytes (defined), -1: raised to claim the
                           page (0 owns it)
    +0x1E  (2 bytes of rounding)

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/msg/msg_wired.pas.  Check: tools/pascal_check.sh.
}
module msg_wired, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'os/os.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'msg/msg.ins.pas';

{ The globals the module defines (ref 7.3.4, Method 2), the block's
  objects in its order with their initial values, the routine in map
  order. }
define
  msg_$sock_lock;                                       { +0x00, zero }
  dpage_va;                                             { +0x14, zero }
  dpage_pa;                                             { +0x18, zero }
  dpage_lock := -1;                                     { +0x1C }

define
  msg_$$send;

{ ---- WIRED_PROC ---- }
%include 'msg/send_internal.pas';           { MSG_$$SEND }
