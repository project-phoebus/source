{ mac_os/mac_os.pas - the MAC_OS module, the MAC layer's OS side.

  Image addresses:
    sau2  0x00E22990  MAC_OS data (WIRED_DATA, 0x8EC bytes)

  One compilation unit: the map's MAC_OS code segments in WIRED_PROC
  (0x11E0 bytes, three module-local routines, then MAC_OS_$OPEN ..
  MAC_$NET_TO_PORT_NUM) and in OS_INIT_PROC (0x134 bytes, MAC_OS_$INIT),
  and its data segment in WIRED_DATA (0x8EC bytes; map symbols
  MAC_OS_$PORTP_TABLE and MAC_OS_$PORT_TABLE).

  The six MAC_ routines lie inside MAC_OS's WIRED_PROC segment and reach
  its block through A5, so they are this unit's (mac/README.md);
  their fragments are mac/*.pas.

  The heading: `module mac_os, wired_proc, wired_data;' (NETBUF's and
  LOG's shape); MAC_OS_$INIT is headed `[section(os_init_proc,
  os_init_data)]' and reaches the block by its absolute address.

  The data, 0x8EC bytes, zero but the broadcast record's host:

    +0x000  mac_os_$port_pkt_tables   8 * 0xF4  the ports' packet-type
                                         tables
    +0x7A0  mac_os_$channel_table  10 * 0x14  the channels
    +0x868  mac_os_$exclusion     0x12   the lock
    +0x87A  (2 bytes: the next object's alignment)

    +0x87C  MAC_OS_$PORTP_TABLE   8 * 4  defined
    +0x89C  MAC_OS_$PORT_TABLE    8 * 8  defined
    +0x8DC  (4 bytes nothing addresses: unused_8dc, a stand-in)
    +0x8E0  mac_os_$broadcast_nexthop  10  network 0, host all ones
    +0x8EA  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each (mac_os/<name>.pas;
  mac/<name>.pas for the MAC_ ones), included below in image order.
  mac_os_$copy_buffer_data is nested in MAC_OS_$SEND (send.pas),
  mac_$copy_to_buffers in MAC_$RECEIVE (mac/receive.pas).

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/mac_os/mac_os.pas.  Check: tools/pascal_check.sh.
}
module mac_os, wired_proc, wired_data;

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
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'mac/mac.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  mac_os_$port_pkt_tables: array[0..7] of mac_os_$port_pkt_table_t;
                                                   { +0x000, zero }
  mac_os_$channel_table: array[0..9] of mac_os_$channel_t;
                                                   { +0x7A0, zero }
  mac_os_$exclusion: ml_$exclusion_t;              { +0x868, zero }

define
  mac_os_$portp_table;                             { +0x87C, zero }
  mac_os_$port_table;                              { +0x89C, zero }

var
  unused_8dc: integer32;                           { +0x8DC, zero: above }
  mac_os_$broadcast_nexthop: rip_$nexthop_t :=
    [network := 0, host_hi := 16#FFFF, host_lo := -1];
                                                   { +0x8E0 }

define
  mac_os_$open;
  mac_os_$close;
  mac_os_$send;
  mac_os_$demux;
  mac_$open;
  mac_$close;
  mac_$send;
  mac_$demux;
  mac_$receive;
  mac_os_$proc2_cleanup;
  mac_os_$arp;
  mac_os_$put_info;
  mac_$net_to_port_num;
  mac_os_$init;

{ ---- WIRED_PROC ---- }
%include 'mac_os/check_range_overlap.pas';  { mac_os_$check_range_overlap }
%include 'mac_os/find_packet_type.pas';     { mac_os_$find_packet_type }
%include 'mac_os/nop.pas';                  { mac_os_$nop           }
%include 'mac_os/open.pas';                 { MAC_OS_$OPEN          }
%include 'mac_os/close.pas';                { MAC_OS_$CLOSE         }
%include 'mac_os/send.pas';                 { MAC_OS_$SEND, its nested
                                              mac_os_$copy_buffer_data }
%include 'mac_os/demux.pas';                { MAC_OS_$DEMUX         }
%include 'mac/open.pas';                    { MAC_$OPEN             }
%include 'mac/close.pas';                   { MAC_$CLOSE            }
%include 'mac/send.pas';                    { MAC_$SEND             }
%include 'mac/demux.pas';                   { MAC_$DEMUX            }
%include 'mac/receive.pas';                 { MAC_$RECEIVE, its nested
                                              mac_$copy_to_buffers  }
%include 'mac_os/proc2_cleanup.pas';        { MAC_OS_$PROC2_CLEANUP }
%include 'mac_os/arp.pas';                  { MAC_OS_$ARP           }
%include 'mac_os/put_info.pas';             { MAC_OS_$PUT_INFO      }
%include 'mac/net_to_port_num.pas';         { MAC_$NET_TO_PORT_NUM  }

{ ---- OS_INIT_PROC ---- }
%include 'mac_os/init.pas';                 { MAC_OS_$INIT          }
