{ pkt/pkt.pas - the PKT module, internet packets.

  Image addresses:
    sau2  0x00E24C9C  PKT data (WIRED_DATA, 0xA8 bytes)

  One compilation unit, `module pkt, wired_proc, wired_data;': the map's
  PKT code segments in WIRED_PROC (PKT_$BLD_INTERNET_HDR ..
  PKT_$PING_SERVER), OS_INIT_PROC (PKT_$INIT, headed
  `[section(os_init_proc, os_init_data)]') and PROCEDURE$
  (PKT_$SAR_INTERNET, `[section(procedure$, data$)]'), and its data
  segment in WIRED_DATA (168 bytes).

  The data:
    +0x00  PKT_$MISSING_NODE     ten 8-byte entries from 1 (defined)
    +0x50  pkt_$spin_lock        4 bytes
    +0x54  pkt_$visibility_seq   4 bytes, 1
    +0x58  PKT_$N_MISSING        2 bytes (defined)
    +0x5A  pkt_$ping_req_hdr     2 bytes, 1: the ping's 2-byte template

    +0x5C  pkt_$short_id         2 bytes, a pinteger
    +0x5E  (2 bytes: pkt_$long_id's alignment)
    +0x60  pkt_$long_id          4 bytes
    +0x64  pkt_$default_flags    2 bytes, NET_IO_$SEND's flags
    +0x66  unused_66             2 bytes, a stand-in for the alignment

    +0x68  pkt_$ping_template    32 bytes, the ping request's info
                                 record (flags 16#10)
    +0x88  pkt_$ping_reply_info  32 bytes, the reply's (flags 16#20)

  The routines live in one fragment file each (pkt/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/pkt/pkt.pas.  Check: tools/pascal_check.sh.
}
module pkt, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';
%include 'rip/rip.ins.pas';
%include 'network/network.ins.pas';
%include 'net_io/net_io.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
define
  pkt_$missing_node;                               { +0x00, zero }

var
  pkt_$spin_lock: integer32;                       { +0x50, zero }
  pkt_$visibility_seq: linteger := 1;              { +0x54 }

define
  pkt_$n_missing;                                  { +0x58, zero }

var
  pkt_$ping_req_hdr: integer := 1;                 { +0x5A }
  pkt_$short_id: pinteger;                         { +0x5C, zero }
  pkt_$long_id: integer32;                         { +0x60, zero }
  pkt_$default_flags: integer;                     { +0x64, zero }
  unused_66: integer;                              { +0x66, stand-in }
  pkt_$ping_template: pkt_$info_t :=
    [flags := 16#10, routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long,
     protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
     field_0c := 16#FFFF];                         { +0x68, the rest
                                                     zero }
  pkt_$ping_reply_info: pkt_$info_t :=
    [flags := 16#20, routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long,
     protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
     field_0c := 16#FFFF];                         { +0x88: the same,
                                                     flags 16#20 }

define
  pkt_$bld_internet_hdr;
  pkt_$brk_internet_hdr;
  pkt_$next_id;
  pkt_$next_long_id;
  pkt_$copy_to_pa;
  pkt_$send_internet;
  pkt_$dump_data;
  pkt_$dat_copy;
  pkt_$recently_missing;
  pkt_$note_visible;
  pkt_$likely_to_answer;
  pkt_$ping_server;
  pkt_$init;
  pkt_$sar_internet;

{ ---- WIRED_PROC ---- }
%include 'pkt/bld_internet_hdr.pas';        { PKT_$BLD_INTERNET_HDR }
%include 'pkt/brk_internet_hdr.pas';        { PKT_$BRK_INTERNET_HDR }
%include 'pkt/next_id.pas';                 { PKT_$NEXT_ID          }
%include 'pkt/next_long_id.pas';            { PKT_$NEXT_LONG_ID     }
%include 'pkt/copy_to_pa.pas';              { PKT_$COPY_TO_PA       }
%include 'pkt/send_internet.pas';           { PKT_$SEND_INTERNET    }
%include 'pkt/dump_data.pas';               { PKT_$DUMP_DATA        }
%include 'pkt/dat_copy.pas';                { PKT_$DAT_COPY         }
%include 'pkt/recently_missing.pas';        { PKT_$RECENTLY_MISSING }
%include 'pkt/note_visible.pas';            { PKT_$NOTE_VISIBLE     }
%include 'pkt/likely_to_answer.pas';        { PKT_$LIKELY_TO_ANSWER }
%include 'pkt/ping_server.pas';             { PKT_$PING_SERVER      }

{ ---- OS_INIT_PROC ---- }
%include 'pkt/init.pas';                    { PKT_$INIT             }

{ ---- PROCEDURE$ ---- }
%include 'pkt/sar_internet.pas';            { PKT_$SAR_INTERNET     }
