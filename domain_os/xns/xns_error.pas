{ xns/xns_error.pas - the XNS_ERROR module, the XNS error protocol: the
  error channel's open and close and the sending of an error packet.

  Image addresses:
    sau2  0x00E2B29C  XNS_ERROR data (WIRED_DATA, 0x78 bytes)

  One compilation unit: the map's XNS_ERROR code segment in WIRED_PROC
  (0x3A8 bytes: the module-local routines, MAYBE_OPEN_ERROR_SOCKET,
  MAYBE_CLOSE_ERROR_SOCKET, XNS_ERROR_$SEND) and its data segment in
  WIRED_DATA (0x78 bytes).  The module's lock, XNS_ERROR_$CLIENT_MUTEX,
  lies in RIP's block (RIP_WIRED; rip/rip.ins.pas).

  The heading: `module xns_error, wired_proc, wired_data;' (PKT's and
  APP's shape; pkt/pkt.pas, app/app.pas).

  The data, 0x78 bytes, zero but where shown:

    +0x00  xns_error_$send_rec      0x48  the request record
                                          XNS_ERROR_$SEND passes to
                                          XNS_IDP_$OS_SEND
    +0x48  unused_48                0x24  a stand-in: nothing addresses
                                          these bytes

    +0x6C  xns_error_$buf_va_high      4  addr(netpool_end), the network
                                          buffer window's end
    +0x70  xns_error_$buf_va_low       4  addr(network_$bufpool), its
                                          start
    +0x74  CLIENT_REF_COUNT            2  defined; zero
    +0x76  XNS_ERROR_$STD_IDP_CHANNEL  2  defined; -1

  The two bounds are univ_ptr, compared signed, with the addresses as
  initial values (ref 3.13.4).

  The routines live in one fragment file each (xns/<name>.pas;
  XNS_ERROR_$SEND in xns/error_send.pas), included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/xns/xns_error.pas.  Check: tools/pascal_check.sh.
}
module xns_error, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'xns/xns.ins.pas';
%include 'xns/xns_idp.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  xns_error_$send_rec: xns_$os_send_rec_t;              { +0x00, zero }
  unused_48: array[16#48..16#6B] of char;               { +0x48, stand-in }
  xns_error_$buf_va_high: univ_ptr := addr(netpool_end);  { +0x6C }
  xns_error_$buf_va_low: univ_ptr := addr(network_$bufpool);
                                                        { +0x70 }

define
  client_ref_count;                                     { +0x74, zero }
  xns_error_$std_idp_channel := 16#FFFF;                { +0x76 }

define
  maybe_open_error_socket;
  maybe_close_error_socket;
  xns_error_$send;

{ ---- WIRED_PROC ---- }
%include 'xns/is_local_addr.pas';           { xns_$is_local_addr }
%include 'xns/pkt_bufs_in_netbuf_pool.pas'; { xns_$pkt_bufs_in_netbuf_pool }
%include 'xns/maybe_open_error_socket.pas'; { maybe_open_error_socket }
%include 'xns/maybe_close_error_socket.pas'; { maybe_close_error_socket }
%include 'xns/error_send.pas';              { XNS_ERROR_$SEND,
                                              xns_$setup_error_header }
