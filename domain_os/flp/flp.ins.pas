{ flp/flp.ins.pas - FLP_ (the floppy disk driver) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  Holds only what the Pascal files use.  No customer insert file
  declares these: the layouts are the image's.  The module is
  flp/flp.pas.  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas,
  io/io.ins.pas and disk/disk.ins.pas before it.
}

const
  { 16#00080008, "bad disk format", stored by EXCS. }
  status_$bad_disk_format = 16#00080008;

  { The driver's own "issue the command again" mark (no status-code
    database entry): EXCS returns it, FLP_DO_IO sets it and loops while
    it comes back. }
  flp_$retry = 16#0008FFFF;

type
  { An unsigned byte (suma's form). }
  flp_$byte_t = [byte] 0..255;

  { The controller's registers, from the base the DCTE supplies
    (main_status and data_reg for its status and data, names that do not
    collide with the routines' status locals and SHAKE's data parameter
    inside `with' statements).  The main status register at 0x10 is read
    as a byte value (FLP_DO_IO) and its bits 6 and 7 tested as set
    members (FLP_$INT: member 7 is the byte's sign): two variants over
    the byte.  The word at 6 is tested whole (EXCS): a word set.
    `[device]': the status is polled in loops and the data register
    read and written once per byte (ref 3.15.3). }
  flp_$regs_t = [device] record
    case integer of
      1: (pad_00: array[0..5] of char;
          w_06: set of 0..15;             { 0x06 }
          pad_08: array[8..15] of char;
          main_status: flp_$byte_t;       { 0x10: main status }
          pad_11: char;
          data_reg: flp_$byte_t;          { 0x12: data register }
          pad_13: char;
          control: flp_$byte_t);          { 0x14: board control }
      2: (pad_00b: array[0..15] of char;
          main_status_bits: set of 0..7); { 0x10: 7 RQM, 6 DIO }
  end;
  flp_$regs_ptr_t = ^flp_$regs_t;

  { An FDC result register, one byte per word: read as a word (EXCS,
    FLP_DO_IO) and its bits tested as members (EXCS: member 4 of a word
    set, in its low byte). }
  flp_$sreg_t = record
    case integer of
      1: (w: pinteger);                   { 0x00 }
      2: (bits: set of 0..15);            { 0x00 }
  end;

  { An FDC command or result block, one byte per word, 0-based (SHAKE
    walks it from its first word, the low byte at +1; EXCS reads words 0
    and 1).  Nine words, the longest block (READ/WRITE DATA, FLP_DO_IO's
    count). }
  flp_$words_t = array[0..8] of pinteger;

  { One controller's slot: the DCTE FLP_$CINIT was given and its register
    base. }
  flp_$ctlr_entry_t = record
    dcte: dcte_ptr_t;                     { 0x00 }
    hw_addr: flp_$regs_ptr_t;             { 0x04 }
  end;

  { One sector's ID in the FORMAT TRACK table (flp_format_track): C, H,
    R, N.  The names are the FDC's fields (cylinder, head, record, size
    code). }
  flp_$id_entry_t = record
    c: flp_$byte_t;                       { 0x00 }
    h: flp_$byte_t;                       { 0x01 }
    r: flp_$byte_t;                       { 0x02 }
    n: flp_$byte_t;                       { 0x03 }
  end;

  { The 10-byte record FLP_$DINIT fills in: copied as two longwords and a
    word, then the word at 6 stored. }
  flp_$pvlabel_info_t = record
    l_00: integer32;                      { 0x00 }
    w_04: pinteger;                       { 0x04 }
    w_06: pinteger;                       { 0x06 }
    w_08: pinteger;                       { 0x08 }
  end;

var
  { FLP_$EC and FLP_$SREGS, the two map symbols inside FLP_'s data
    segment (.DATA), defined in flp/flp.pas: the eventcount FLP_$INT
    advances and EXCS waits on, and the result registers FLP_$INT
    collects (0-based: FLP_$INT's pointer starts at the array). }
  flp_$ec: extern ec_$eventcount_t;
  flp_$sregs: extern array[0..3] of flp_$sreg_t;

{ Routine headings, in map order: FLP_'s WIRED_PROC segment, then its
  .TEXT segment.  The map symbols without `$' (FLP_DO_IO, EXCS, SHAKE)
  are globals too.  The bodies repeat the full heading (ref 7.3.4,
  Method 2). }

{ FLP_$INT (flp/int.pas), the interrupt routine, entered through
  FLP_DCTE's disk_do_io field. }
function flp_$int(in dcte: dcte_t): boolean;
  extern;

{ FLP_$REVALIDATE - clear the disk-change flag of a volume's drive. }
procedure flp_$revalidate(in vol: disk_$volume_t);
  extern;

{ FLP_DO_IO (flp/flp_do_io.pas): param_3 and zero are not read. }
procedure flp_do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; zero: integer;
                    out result: boolean);
  options(extern, val_param);

{ FLP_$DO_IO - the driver's I/O entry. }
procedure flp_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
  extern;

{ FLP_$CINIT - initialize a floppy controller. }
function flp_$cinit(var dcte: dcte_t): integer32;
  extern;

{ FLP_$DINIT (flp/dinit.pas): jump table entry 2 (+0x08), the unit
  initialization. }
function flp_$dinit(unit: pinteger; ctlr: pinteger;
                    var num_blocks: integer32;
                    out sec_per_track: pinteger; out num_heads: pinteger;
                    out pvlabel_info: flp_$pvlabel_info_t;
                    out flags: pinteger): integer32;
  options(extern, val_param);

{ FLP_$SHUTDOWN - mark a drive inactive and count the active ones. }
function flp_$shutdown(ctlr: pinteger; unit: pinteger): integer;
  options(extern, val_param);

{ EXCS (flp/excs.pas): execute an FDC command. }
function excs(var cmd: univ flp_$words_t; in count: integer;
              in vol: disk_$volume_t): integer32;
  extern;

{ SHAKE (flp/shake.pas): move a block between memory and the FDC's data
  register; `univ': the callers pass blocks and single words. }
function shake(var data: univ flp_$words_t; in count: integer;
               in dir: integer): integer32;
  extern;
