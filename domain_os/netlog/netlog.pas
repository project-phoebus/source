{ netlog/netlog.pas - the NETLOG module, network event logging.

  Image addresses:
    sau2  0x00E85684  NETLOG data (.DATA, 0x84 bytes)

  One compilation unit, one code segment and one data segment: the map's
  NETLOG code segment in .TEXT (0x464 bytes: NETLOG_$CNTL, also named
  NETLOG_$PROC_START, NETLOG_$LOG_IT, NETLOG_$SEND_PAGE) and its NETLOG
  data segment in .DATA (0x84 bytes: NETLOG_$DATA_START at its start,
  NETLOG_$DONE_CNT, NETLOG_$DATA_END one past it).

  The map's second NETLOG code segment is 4 zero bytes holding the
  marker NETLOG_$PROC_END, no code.  The hand-written NETLOG_ASM data
  segment (WIRED_DATA) holds the six cells the routines name absolutely
  (netlog/netlog.ins.pas).  The heading names no sections: the code is
  .TEXT's and the block .DATA's, the defaults (ref 7.1.1).

  The data, 0x84 bytes: the first 16 bytes are pkt_info's initial value,
  every other byte zero.

    +0x00  pkt_info           0x20  PKT_$BLD_INTERNET_HDR's; flags 4,
                                    routing_type 2, addr_type 2, protocol
                                    0x8031, retry_limit 1, field_0a 0,
                                    field_0c 16#FFFF, the addr's first
                                    word 0
    +0x20  wired_pages        0x28  from 1

    +0x48  pkt_hdr            0x0A  the packet header's fields
    +0x52  (2 bytes)                alignment before the next longword
    +0x54  unused_54          4     nothing addresses it
    +0x58  buffer_va          8     from 1
    +0x60  buffer_ppn         8     from 1
    +0x68  spin_lock          4

    +0x6C  NETLOG_$DONE_CNT   4     (map symbol, defined here)
    +0x70  page_counts        4     from 1
    +0x74  current_buf_ptr    4
    +0x78  wired_page_count   2
    +0x7A  send_page_index    2
    +0x7C  current_buf_index  2

    +0x7E  initialized        1     boolean
    +0x80  ok_to_send         1     boolean, a word's high byte after
                                    initialized
    +0x81  (3 bytes)                the block rounded to a longword

  These are variables, not one record, as SUMA's and TPAD's blocks are:
  no routine copies or compares the block, and the map names
  NETLOG_$DONE_CNT inside it, a defined variable (ref 7.2.2, Method 2),
  extern in netlog/netlog.ins.pas.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/netlog/netlog.pas.  Check: tools/pascal_check.sh.
}
module netlog;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'node/node.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'mst/mst.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';

{ The global routines and variable this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above).  Where the defined variable goes among
  the module's own: see the TODO(pascal) in log/log.pas. }
define
  netlog_$cntl;
  netlog_$log_it;
  netlog_$send_page;

var
  pkt_info: pkt_$info_t := [flags := 4, routing_type := pkt_$routing_inet,
                            addr_type := pkt_$addr_long,
                            protocol := 16#8031, retry_limit := 1,
                            field_0a := 0, field_0c := 16#FFFF];
                                          { +0x00 }
  wired_pages: array[1..netlog_max_wired_pages] of integer32;
                                          { +0x20 }
  pkt_hdr: netlog_$pkt_hdr_t;             { +0x48 }
  unused_54: integer32;                   { +0x54 }
  buffer_va: array[1..2] of integer32;    { +0x58 }
  buffer_ppn: array[1..2] of integer32;   { +0x60 }
  spin_lock: integer32;                   { +0x68 }

define
  netlog_$done_cnt;                       { +0x6C }

var
  page_counts: array[1..2] of integer;    { +0x70 }
  current_buf_ptr: integer32;             { +0x74 }
  wired_page_count: integer;              { +0x78 }
  send_page_index: integer;               { +0x7A }
  current_buf_index: integer;             { +0x7C }
  initialized: boolean;                   { +0x7E }
  ok_to_send: boolean;                    { +0x80 }

{ ---- .TEXT ---- }
%include 'netlog/cntl.pas';                 { NETLOG_$CNTL }
%include 'netlog/log_it.pas';               { NETLOG_$LOG_IT }
%include 'netlog/send_page.pas';            { NETLOG_$SEND_PAGE }
