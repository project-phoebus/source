{ netlog/netlog.ins.pas - NETLOG (network event logging) types, variables
  and routine headings, for the Domain Pascal tree.

  Only what the Pascal files use: the log entry and page, the packet
  header template, the kinds set, the hand-written NETLOG_ASM cells, the
  module's map-global NETLOG_$DONE_CNT, the module's markers and the
  three headings.  The module is netlog/netlog.pas.  No customer insert
  file declares these.  Include base/base.ins.pas, ec/ec.ins.pas and
  time/time.ins.pas before it.
}

const
  { The entries of a page: NETLOG_$LOG_IT compares the count with it; 39
    entries of 26 bytes are the 0x3F6 data bytes NETLOG_$SEND_PAGE
    passes. }
  netlog_entries_per_page = 39;

  { The wired page handles' capacity: a constant cell of NETLOG_$CNTL
    and the bound of its count. }
  netlog_max_wired_pages = 10;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  netlog_$byte_t = [byte] 0..255;

  { The kinds that are logged, a set of 32 (bit positions 0..31):
    NETLOG_$LOG_IT tests a member held in a register (a longword set);
    NETLOG_$CNTL tests members 21 and 20 and the difference with [20,
    21]. }
  netlog_$kinds_t = set of 0..31;

  { One log entry, 26 bytes.  NETLOG_$LOG_IT stores the fields in order
    through the element's address: bytes (kind, process_id, param4), the
    clock's middle longword, the UID as one 8-byte record, the words.
    The fields are named with the prefix e_: NETLOG_$LOG_IT stores them
    inside a `with' over the element (netlog/log_it.pas), where
    unprefixed names would hide its parameters kind, uid, param3 ..
    param8. }
  netlog_$entry_t = record
    e_kind: netlog_$byte_t;               { 0x00 }
    e_process_id: netlog_$byte_t;         { 0x01 }
    e_timestamp: integer32;               { 0x02 }
    e_uid: uid_$t;                        { 0x06 }
    e_param3: integer;                    { 0x0E }
    e_param4: netlog_$byte_t;             { 0x10 }
    e_pad_11: netlog_$byte_t;             { 0x11 }
    e_param5: integer;                    { 0x12 }
    e_param6: integer;                    { 0x14 }
    e_param7: integer;                    { 0x16 }
    e_param8: integer;                    { 0x18 }
  end;

  { A page of entries, indexed from 1: NETLOG_$LOG_IT forms count * 26
    and stores at -0x1A + offset from the page's address plus that, the
    lower bound folded in (the `with' or common-subexpression form).
    The page is reached through the longword current_buf_ptr
    (netlog/netlog.pas), converted at the dereference. }
  netlog_$page_t = array[1..netlog_entries_per_page] of netlog_$entry_t;
  netlog_$page_ptr_t = ^netlog_$page_t;

  { The packet header template, 10 bytes at +0x48 of the block, passed
    whole to PKT_$BLD_INTERNET_HDR with the length 10: two words
    NETLOG_$CNTL sets to 99 and 1, the longword and word
    NETLOG_$SEND_PAGE copies in. }
  netlog_$pkt_hdr_t = record
    type1: integer;                       { 0x00 }
    type2: integer;                       { 0x02 }
    done_cnt: integer32;                  { 0x04 }
    entry_cnt: integer;                   { 0x08 }
  end;

var
  { The six cells of the hand-written NETLOG_ASM data segment
    (WIRED_DATA), map symbols named by their absolute addresses (no
    compiled module defines them):
    - NETLOG_$OK_TO_LOG, NETLOG_$OK_TO_LOG_SERVER: cleared and stored as
      bytes (NETLOG_$CNTL), booleans;
    - NETLOG_$KINDS: the set above;
    - NETLOG_$EC: an eventcount (12 bytes, ec/ec.ins.pas), advanced by
      NETLOG_$LOG_IT;
    - NETLOG_$NODE: stored as a longword, pushed as a longword and by
      address: integer32;
    - NETLOG_$SOCK: stored as a word: integer. }
  netlog_$ok_to_log: extern boolean;
  netlog_$ok_to_log_server: extern boolean;
  netlog_$kinds: extern netlog_$kinds_t;
  netlog_$ec: extern ec_$eventcount_t;
  netlog_$node: extern integer32;
  netlog_$sock: extern integer;

  { NETLOG_$DONE_CNT (map symbol, +0x6C of the NETLOG data segment,
    .DATA): the pages completed, incremented, cleared and copied as a
    longword: integer32.  Defined in netlog/netlog.pas. }
  netlog_$done_cnt: extern integer32;

  { The module's markers: NETLOG_$PROC_START (NETLOG_$CNTL's address,
    which the map gives both names), NETLOG_$PROC_END (inside the 4 zero
    bytes of the second NETLOG code segment, no code),
    NETLOG_$DATA_START and NETLOG_$DATA_END (the data block's first byte
    and one past its last).  NETLOG_$CNTL passes their addresses to
    MST_$WIRE_AREA as cells.  They are no objects of the module: labels
    the build places, as MT_$PROC_START and the others
    (mt/README.md).  Extern chars, of which only the address is
    used. }
  netlog_$proc_start: extern char;
  netlog_$proc_end: extern char;
  netlog_$data_start: extern char;
  netlog_$data_end: extern char;

{ Routine headings, in map order (NETLOG, .TEXT).  The bodies repeat the
  full heading (ref 7.3.4, Method 2). }

{ NETLOG_$CNTL - start, stop or retune network event logging. }
procedure netlog_$cntl(in cmd: integer; in node: integer32; in sock: integer;
                       in kinds: netlog_$kinds_t; out status: status_$t);
  extern;

{ NETLOG_$LOG_IT - log one network event, if its kind is logged. }
procedure netlog_$log_it(kind: integer; uid: uid_$t; param3: integer;
                         param4: integer; param5: integer; param6: integer;
                         param7: integer; param8: integer);
  options(extern, val_param);

{ NETLOG_$SEND_PAGE - send the page to the logging server. }
procedure netlog_$send_page; extern;
