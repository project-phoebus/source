{ log/log.ins.pas - LOG_, the system error log: constants, types, the two
  global variables and the routine headings, for the Domain Pascal tree.

  The LOG module (log/log.pas) includes it, and so will other subsystems'
  modules that call LOG routines or reach LOG_$LOGFILE_PTR
  (PMAP_$PURIFIER_L clears it).  Include base/base.ins.pas and
  time/time.ins.pas before it.

  Apollo's customer insert files of SR10.2 have nothing for this
  subsystem: no log.ins.pas, and errlog.ins.pas is the user library's
  error-log package (errlog_$open, errlog_$close, ...), another thing.
  The layouts are the image's.
}

const
  log_$buffer_size = 1024;                { the page, 1024 bytes (LOG_$READ's
                                            worker compares with it) }
  log_$max_entry_words = 100;             { LOG_$ADD's limit }
  log_$max_index = 510;                   { the last word index of the
                                            page (LOG_$ADD) }
  { The mark of a valid record in low memory, 16#ABCDEF01 (LOG_$INIT
    compares with it).  Written as the negative integer32 it is:
    16#ABCDEF01 is above the largest integer32. }
  log_$pending_magic = -16#543210FF;

  { Entry types.  LOG_$INIT logs 0 and 5; LOG_$SHUTDN 4; MEM_$ECCC_LOG
    2, a corrected memory error; MEM_$ECCC6_LOG 7, a corrected memory
    error with the board's registers. }
  log_$type_init = 0;
  log_$type_ecc_error = 2;
  log_$type_shutdown = 4;
  log_$type_crash = 5;
  log_$type_ecc6_error = 7;
  { IO_$LOG_SELF_TESTS logs 15: a controller whose PROM self-test
    failed. }
  log_$type_self_test = 15;

type
  { The data words of an entry: at most log_$max_entry_words less the
    4 words of the header (LOG_$ADD drops longer entries). }
  log_$data_t = array[1..log_$max_entry_words-4] of integer;

  { A log entry as it lies in the page: the header and the data after
    it.  LOG_$ADD writes size, the type and the time through a pointer to
    it, and the data words from +8.  `type' is a reserved word:
    entry_type here. }
  log_$entry_t = record
    size: integer;                        { 0x00: words, header included }
    entry_type: integer;                  { 0x02 }
    timestamp: time_$clockh_t;            { 0x04 }
    data: log_$data_t;                    { 0x08 }
  end;
  log_$entry_ptr_t = ^log_$entry_t;

  { The mapped log page, 0x400 bytes: the header, then the entries.
    Entry index i is the word at byte 2 + 2i, which LOG_$ADD reaches as a
    1-based word array at +4 (element i at 4 + 2(i - 1)).  head is the
    index of the oldest entry, tail of the next free slot. }
  log_$page_t = record
    head: integer;                        { 0x00 }
    tail: integer;                        { 0x02 }
    data: array[1..log_$max_index] of integer; { 0x04..0x3FF }
  end;
  log_$page_ptr_t = ^log_$page_t;

  { The page as words, as LOG_$READ hands it out: the reader's buffer,
    and the source of its copy loop at a byte offset into the page (both
    1-based word arrays). }
  log_$buf_t = array[1..log_$buffer_size div 2] of integer;
  log_$buf_ptr_t = ^log_$buf_t;

  { CRASH_$RECORD (the map's CRASH_RECORD segment, 0xC bytes): the
    magic, then the 8 bytes LOG_$INIT logs as a type 5 entry. }
  crash_$record_t = record
    magic: integer32;                     { 0x00 }
    data: array[1..8] of char;            { 0x04 }
  end;

  { LOG_$LAST_ENTRY: the copy of the last entry LOG_$ADD wrote, a magic
    and then the entry's fields.  LOG_$ADD writes 0x4, 0x6, 0x8 and the
    data from 0xC; LOG_$INIT reads them back. }
  log_$last_entry_t = record
    magic: integer32;                     { 0x00 }
    size: integer;                        { 0x04 }
    entry_type: integer;                  { 0x06 }
    timestamp: time_$clockh_t;            { 0x08 }
    data: log_$data_t;                    { 0x0C }
  end;

var
  { The two global variables of the LOG_ data segment (WIRED_DATA, 0x1C
    bytes), map symbols LOG_$LOGFILE_UID (+0x00) and LOG_$LOGFILE_PTR
    (+0x14).  Declared extern here and defined in log/log.pas (ref 7.2.2,
    Method 2: "If the extern clause is stored in an %include file that
    happens to end up in a file with a matching define statement no harm
    is done"); the segment's layout is given there.
    - LOG_$LOGFILE_UID: the log file's UID, 8 bytes: LOG_$INIT copies it
      and passes it by address;
    - LOG_$LOGFILE_PTR: the mapped page, nil until LOG_$INIT has wired it
      (LOG_$SHUTDN, LOG_$ADD and LOG_$READ's worker test it). }
  log_$logfile_uid: extern uid_$t;
  log_$logfile_ptr: extern log_$page_ptr_t;

{ Routine headings.  The LOG routines that are global symbols in the SAU2
  map, in map order.  The module (log.pas) repeats each heading on its
  body (ref 7.3.4, Method 2).  The module-local log_$read_internal and
  the nested log_$check_op_status are declared only there. }

{ LOG_$SHUTDN - log the shutdown and let go of the log page. }
procedure log_$shutdn; extern;

{ LOG_$UPDATE - hand back the wired page's handle when the log has
  changed. }
function log_$update: integer32; extern;

{ LOG_$ADD - append a timestamped entry to the log page. }
procedure log_$add(entry_type: integer; in data: univ log_$data_t;
                   data_len: integer);
  options(extern, val_param);

{ LOG_$READ - read the log page from its start. }
procedure log_$read(out buffer: univ log_$buf_t; in max_len: pinteger;
                    out actual_len: pinteger); extern;

{ LOG_$READ2 - read the log page from a byte offset. }
procedure log_$read2(out buffer: univ log_$buf_t; offset: pinteger;
                     max_len: pinteger; out actual_len: pinteger);
  options(extern, val_param);

{ LOG_$INIT - open the system error log, and log what the last boot left. }
procedure log_$init; extern;
