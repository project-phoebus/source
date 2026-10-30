{ pacct/pacct.ins.pas - PACCT_ (process accounting), for the Domain Pascal
  tree.

  What the Pascal files use: the accounting record, the compressed time
  type and the headings of the six map-global routines.  No customer
  insert file declares these.  Include base/base.ins.pas and
  acl/acl.ins.pas before it.
}

const
  { The sizes: a record, and the mapped window. }
  pacct_record_size = 128;
  pacct_buffer_size = 32768;

  { The seconds from 1970 to 1980. }
  unix_epoch_offset = 315532800;

  { The divisor of the clock, pushed three times by
    pacct_$clock_to_comp. }
  pacct_tick_divisor = 4167;

  { The FILE_ request and size words PACCT passes (constant cells of
    PACCT_$START and PACCT_$LOG). }
  pacct_start_attr_req = 16#0401;
  pacct_log_attr_req = 16#0004;
  file_attr_info_size = 122;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), suma's form. }
  pacct_$byte_t = [byte] 0..255;

  { A compressed value: pacct_$compress's word result, stored as a
    word. }
  comp_t = pinteger;

  { The record's flag word (bit 0 the first argument's boolean, bit 1
    the second's).  PACCT_$LOG clears the word, then stores each boolean
    into its bit: boolean fields of a packed record at the word's two
    low bits, and the whole word as an integer for the clear: a variant.
    The fields' names are PACCT_$LOG's arguments'. }
  pacct_$flags_t = packed record
    case integer of
      1: (word: integer);
      2: (unused: 0..16383;               { bits 15..2 }
          su_flag: boolean;               { bit 1 }
          fork_flag: boolean);            { bit 0 }
  end;

  { The accounting record, 0x80 bytes (pacct/log.pas has each field's
    store).  PACCT_$LOG builds it in its frame and copies it whole into
    the mapped file, 32 longwords.  The SID and protection blocks are
    ACL's types (copied whole from ACL_$GET_RE_ALL_SIDS's records). }
  pacct_record_t = record
    ac_flags: pacct_$flags_t;             { 0x00 }
    ac_stat: pacct_$byte_t;               { 0x02 }
    ac_pad_03: char;                      { 0x03 }
    ac_sids: acl_sid_block_t;             { 0x04 }
    ac_prot: acl_prot_info_t;             { 0x28 }
    ac_devno: integer32;                  { 0x34 }
    ac_btime: integer32;                  { 0x38 }
    ac_utime: comp_t;                     { 0x3C }
    ac_stime: comp_t;                     { 0x3E }
    ac_etime: comp_t;                     { 0x40 }
    ac_zero_42: integer32;                { 0x42 }
    ac_io_write: comp_t;                  { 0x46 }
    ac_io_read: comp_t;                   { 0x48 }
    ac_proc_uid: uid_$t;                  { 0x4A }
    ac_comm: array[1..32] of char;        { 0x52 }
    ac_mem: comp_t;                       { 0x72 }
    ac_pad_74: array[1..12] of char;      { 0x74 }
  end;
  pacct_record_ptr_t = ^pacct_record_t;

  { The process's times PACCT_$LOG reads, the longwords at +0x08 and
    +0x0C (elements 2 and 3).  From 0. }
  pacct_$times_t = array[0..3] of integer32;

  { The command name: bytes indexed from 1, at most 32 of them read.
    tty/tty.ins.pas tty_$chars_t's one-element idiom would serve; the
    bound is the copy's. }
  pacct_$comm_t = array[1..32] of char;

{ The routines, in map order.  Their callers: PACCT_$INIT OS_$INIT;
  PACCT_$SHUTDN one compiled caller; PACCT_$START and PACCT_$STOP the
  system-call table; PACCT_$ON one compiled caller and the table;
  PACCT_$LOG PROC2's delete cleanup.  Every argument by address: the
  default convention. }

{ PACCT_$INIT - accounting off at boot. }
procedure pacct_$init; extern;

{ PACCT_$SHUTDN - stop accounting at shutdown. }
procedure pacct_$shutdn; extern;

{ PACCT_$START - turn accounting on to a file (the system call). }
procedure pacct_$start(in file_uid: uid_$t; in unused: integer32;
                       out status: status_$t); extern;

{ PACCT_$STOP - turn accounting off (the system call). }
procedure pacct_$stop; extern;

{ PACCT_$ON - whether accounting is on. }
function pacct_$on: boolean; extern;

{ PACCT_$LOG - write a terminated process's accounting record. }
procedure pacct_$log(in fork_flag: boolean; in su_flag: boolean;
                     in exit_status: integer;
                     in start_clock: time_$clock_t;
                     in proc_times: univ pacct_$times_t;
                     in io_write_count: integer32;
                     in io_read_count: integer32;
                     in tty_uid: uid_$t; in proc_uid: uid_$t;
                     in comm_ptr: univ pacct_$comm_t;
                     in comm_len: integer); extern;
