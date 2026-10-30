{ ring/ringlog.ins.pas - RINGLOG_ (the ring's packet log), for the Domain
  Pascal tree.

  The log buffer, the RINGLOG_ block's map symbols and the headings of
  RINGLOG_$LOGIT and RINGLOG_$CNTL.  No customer insert file declares
  these.  Include base/base.ins.pas and pkt/pkt.ins.pas before it (a
  file of its own, not ring/ring.ins.pas, because ring/ring.ins.pas's
  users do not all include pkt/pkt.ins.pas).  The module is
  ring/ringlog_.pas.
}

type
  { The nodes and flags of a log entry, 8 bytes at its +0x02, a packed
    record (ref 3.10.7): three 20-bit fields and four booleans in the
    bit string from the first byte's top bit.  No routine addresses bit
    63, unused_0. }
  ringlog_$nodes_t = packed record
    node_a: 0..16#FFFFF;                  { bits 0..19 }
    node_b: 0..16#FFFFF;                  { bits 20..39 }
    node_c: 0..16#FFFFF;                  { bits 40..59 }
    inbound: boolean;                     { bit 60 }
    valid: boolean;                       { bit 61 }
    send: boolean;                        { bit 62 }
    unused_0: boolean;                    { bit 63 }
  end;

  { An entry of the log buffer, 0x2E bytes, from +2 of the buffer, after
    its index word.  NET_IO_$SEND stores the transmit status into the
    word at the entry's end, the last of the thirteen header words: a
    variant arm (xmit_status). }
  ringlog_$entry_t = record
    sock_byte_02: pkt_$byte_t;            { 0x00 }
    sock_byte_03: pkt_$byte_t;            { 0x01 }
    nodes: ringlog_$nodes_t;              { 0x02 }
    field_0c: integer32;                  { 0x0A }
    field_10: integer32;                  { 0x0E }
    pkt_type: pinteger;                   { 0x12 }
    case integer of
      1: (pkt_words: array[0..12] of pinteger);     { 0x14 }
      2: (unused_14: array[0..11] of pinteger;      { 0x14 }
          xmit_status: pinteger);                   { 0x2C }
  end;

  { The log buffer, 0x11FC bytes (the map's overlay section RINGLOG_$DATA;
    2 + 100 * 0x2E = 0x11FA, and the word unused_11fa, whose address
    RINGLOG_$CNTL gives MST_$WIRE_AREA as the end). }
  ringlog_$data_t = record
    index: integer;                       { 0x0000 }
    entries: array[0..99] of ringlog_$entry_t;  { 0x0002 }
    unused_11fa: integer;                 { 0x11FA }
  end;

  { The header seen as words from 1, the source of an entry's pkt_words:
    RINGLOG_$LOGIT reads word (hdr_size + 0x1E) div 2 + 1 onward.  0x5C
    bytes, pkt_$hdr_t's size. }
  ringlog_$hdr_words_t = array[1..46] of pinteger;
  ringlog_$hdr_words_ptr_t = ^ringlog_$hdr_words_t;

  { RINGLOG_$CNTL's second argument: the filter id for command 5, a
    socket filter's boolean for 6..8, and the buffer the copy fills for
    0..2: a variant record, `univ' in the heading. }
  ringlog_$cntl_param_t = record
    case integer of
      1: (id: integer32);
      2: (filter: boolean);
      3: (buf: ringlog_$data_t);
  end;

{ RINGLOG_$DATA (the map's RINGLOG_$DATA load section, 0x11FC bytes): a
  load section with no module segment in it, an overlay section (ref
  3.14 p. 3-52; 7.2.4, Method 4; proc2/proc2_data.ins.pas's PROC2_$DATA),
  every unit that includes this file sharing it. }
var (ringlog_$data)
  ringlog_$data: ringlog_$data_t;

var
  { RING_$LOGGING_NOW (map symbol, +0x38 of RINGLOG_'s data segment): the
    log is on. }
  ring_$logging_now: extern boolean;

  { The RINGLOG_ block's other map symbols, defined by ring/ringlog_.pas:
    RINGLOG_$ID (+0x2C, the node filter), and the three socket filters
    RINGLOG_$MBX_SOCK (+0x32), RINGLOG_$WHO_SOCK (+0x34) and
    RINGLOG_$NIL_SOCK (+0x36): when true, filtering is disabled. }
  ringlog_$id: extern integer32;
  ringlog_$mbx_sock: extern boolean;
  ringlog_$who_sock: extern boolean;
  ringlog_$nil_sock: extern boolean;

{ RINGLOG_$LOGIT - record a packet in the ring log. }
function ringlog_$logit(in inbound: boolean; in hdr: univ pkt_$hdr_t):
  integer;
  extern;

{ RINGLOG_$CNTL - control the ring log. }
procedure ringlog_$cntl(in cmd: integer; var param: univ ringlog_$cntl_param_t;
                        out status: status_$t);
  extern;

{ RINGLOG_$CNTL's commands (its `case cmd of', and the copy-out test
  `cmd in [0..2]').  No Apollo insert declares them. }
const
  ringlog_$cmd_start = 0;
  ringlog_$cmd_stop_copy = 1;
  ringlog_$cmd_copy = 2;
  ringlog_$cmd_clear = 3;
  ringlog_$cmd_stop = 4;
  ringlog_$cmd_start_filtered = 5;
  ringlog_$cmd_set_nil_sock = 6;
  ringlog_$cmd_set_who_sock = 7;
  ringlog_$cmd_set_mbx_sock = 8;
