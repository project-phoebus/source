{ base/base.ins.pas - the kernel's base types, for the Domain Pascal tree.

  What the Pascal files use of the base types.  The original kernel was
  compiled against Apollo's /sys/ins/base.ins.pas; the SR10.2 customer
  copy is sr10.2-install's sys/ins/base.ins.pas ("BASE.INS.PAS,
  /sys/ins, ceb-jrw, 01/02/89").

  The kernel's copy may differ, so each declaration says where its
  layout comes from (status_$t, uid_$t, pinteger, linteger and
  time_$clock_t follow the customer file).  Add declarations as the
  translated files need them; do not invent fields.

  The SAU and its optional parts (base/config.ins.pas) come first, so
  every module, which includes this file once, has them.
}

%include 'base/config.ins.pas';

const
  status_$ok = 0;                         { customer base.ins.pas: `status_$ok
                                            = 0' }

  { 16#000B000E, "hangup fault" (OS / terminal manager, stcode.db.10.2).
    No insert file of the SR10.2 install declares it; the name is made
    from the text, as the other terminal manager codes' names are
    (status_$invalid_line_number 16#000B0007, ...).  TTY_$I_INIT puts it
    in the hangup signal entry (tty/i_init.pas). }
  status_$hangup_fault = 16#000B000E;

  { 16#000B000D, "requested line or operation not implemented" (OS /
    terminal manager, stcode.db.10.2).  No insert file of the SR10.2
    install declares it.  TTY_$I_GET_DESC stores it when the line's DTTE
    has no descriptor (tty/i_get_desc.pas). }
  status_$requested_line_or_operation_not_implemented = 16#000B000D;

  { 16#000B0006, "asynchronous fault occurred while waiting for input"
    (OS / terminal manager, stcode.db.10.2).  SIO_$K_TIMED_BREAK stores
    it when a quit ends its wait (sio/k_timed_break.pas). }
  status_$async_fault_while_waiting_for_input = 16#000B0006;

  { 16#000B0007, "invalid line number supplied" (OS / terminal manager,
    stcode.db.10.2).  No insert file of the SR10.2 install declares it.
    KBD_$GET_DESC stores it for a line above 3 (kbd/get_desc.pas). }
  status_$invalid_line_number = 16#000B0007;

  { The maximum length of a pathname, as the customer base.ins.pas
    declares it, `name_$long_pnamlen_max = 1023;' ("max length of long
    pathname"), for name_$long_pname_t below. }
  name_$long_pnamlen_max = 1023;

  { The maximum length of an entry name, as the customer base.ins.pas
    declares it, `name_$long_complen_max = 255;' ("max length of long
    entry name"), for name_$long_name_t below (added for FLOP). }
  name_$long_complen_max = 255;

  { The pre-SR10 entry name's length, as the customer base.ins.pas
    declares it (sys/ins, line 107), `name_$complen_max = 32;' ("max
    length of entry name (obsolete ..)"), for name_$name_t below. }
  name_$complen_max = 32;

type
  { status_$t, as the customer base.ins.pas declares it:

        status_$t = PACKED RECORD CASE integer OF
            1:  (fail:  boolean;
                 subsys: 0..127;
                 modc: 0..255;
                 code: integer);
            2:  (all: integer32);
            END;

    The packed layout (ref 3.10.7, Table 3-3): fail is 1 bit, subsys 7
    and modc 8, the first word, fail its most significant bit; code, an
    integer, takes 16 bits word aligned, so it is the low word at offset
    2; all is the whole longword.  So a status code such as 16#00350005
    reads as subsys 0, modc 16#35, code 5 (fail and subsys are the top
    byte, modc the next), and the failure bit is bit 31.  The TTY routines use `all' only, which is the same longword
    whatever the first variant's layout.  LOG's log_$check_op_status
    tests `code' as the word at offset 2 of the status, as this layout
    has it (NAME_$CR_FILE tests its status the same way). }
  status_$t = packed record
    case integer of
      1: (fail: boolean;                  { 0x00, bit 15 of the word }
          subsys: 0..127;                 { 0x00, bits 14..8 }
          modc: 0..255;                   { 0x01 }
          code: integer);                 { 0x02 }
      2: (all: integer32);                { 0x00 }
  end;

  { A UID: two longwords, as the customer base.ins.pas declares it:
    `uid_$t = PACKED RECORD high: integer32; low: integer32; END'.
    Packed or not, integer32 fields are 32 bits word aligned (ref
    3.10.7, Table 3-3), the same 8 bytes; the image compares two UIDs as
    two longwords (TTY_$K_SIMULATE_TERMINAL_INPUT). }
  uid_$t = packed record
    high: integer32;                      { 0x00 }
    low: integer32;                       { 0x04 }
  end;

  { The customer file's unsigned subranges ("positive 16 bit integer",
    "positive 31 bit integer"), with its names. }
  pinteger = 0..65535;
  linteger = 0..2147483647;

  { The high 32 bits of the clock (customer file: `time_$clockh_t =
    linteger'). }
  time_$clockh_t = linteger;

  { The 48-bit clock: six bytes, word aligned.  The customer
    base.ins.pas declares it with these two variants and these names:

        time_$clock_t = [aligned(1)] PACKED RECORD CASE integer OF
            1:  (high:  time_$clockh_t;
                 low:  pinteger);
            2:  (high16:  pinteger;
                 low32:  linteger);
            END;

    under `%WORD_ALIGNMENT' for SR10 68k.  The image uses the second
    variant: tty_$i_wait builds a timeout as high16 := 0 and low32 := a
    product, a longword store that straddles the first variant's fields;
    KBD, SIO and NETWORK read the same view.  TIME_$ADVANCE passes the
    clock on to TIME_$Q_ADD_CALLBACK, which reads it in the first
    variant: one type, both views.  Here it is an unpacked record
    without the attribute: the fields are word and longword sized and
    word aligned either way, which gives the same layout, and the
    packing rules for 31-bit subranges are not known. }
  time_$clock_t = record
    case integer of
      1: (high: time_$clockh_t;           { 0x00 }
          low: pinteger);                 { 0x04 }
      2: (high16: pinteger;               { 0x00 }
          low32: linteger);               { 0x02 }
  end;

  { A pathname, as the customer base.ins.pas declares it:
    `name_$long_pname_t= ARRAY [1..name_$long_pnamlen_max+1] OF char;'.
    The pathname parameters of name/name.ins.pas take it `univ'
    (LOG_$INIT passes a 36-character constant, log/init.pas). }
  name_$long_pname_t = array[1..name_$long_pnamlen_max+1] of char;

  { An entry name, as the customer base.ins.pas declares it:
    `name_$long_name_t = ARRAY [1..name_$long_complen_max+1] OF char;'.
    The leaf-name parameters of dir/dir.ins.pas take it `univ' (FLOP
    passes a 3-character constant, flop/boot.pas; added for FLOP). }
  name_$long_name_t = array[1..name_$long_complen_max+1] of char;

  { The pre-SR10 entry name, as the customer base.ins.pas declares it
    (sys/ins, line 113): `name_$name_t = ARRAY [1..name_$complen_max] OF
    char;'.  DIR_$OLD_ADD_BAKU copies its name argument as such an
    array, 32 bytes (dir/old_add_baku.pas). }
  name_$name_t = array[1..name_$complen_max] of char;

var
  { UID_$NIL (the first symbol of the map's UID_LIST segment), as the
    customer base.ins.pas declares it: `VAR uid_$nil: EXTERN uid_$t;'.
    TTY_$I_INIT and TTY_$K_RESET copy it with its absolute address,
    another unit's variable. }
  uid_$nil: extern uid_$t;
