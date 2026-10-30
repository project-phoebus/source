{ sio2681/sio2681.ins.pas - SIO2681_ (the 2681 DUART driver) types,
  variables and routine headings, for the Domain Pascal tree.

  The routines are the SIO_IO module's (sio2681/sio2681.pas).  Include
  base/base.ins.pas and sio/sio.ins.pas before it.
}

const
  { The chips SIO2681_$PTRS has room for: two 16-byte entries before
    SIO2681_$INT1_RTE; SIO2681_$INIT's static table holds the two stubs'
    addresses (8 bytes). }
  sio2681_max_chips = 2;

type
  { The chip's 32 registers, a device (ref 3.15.3), bytes.  Each register
    is read as one thing and written as another at the same offset; the
    names give both.  Every register is a char.  Channel B's register
    pointer points at +0x10, so the first eight names serve it too. }
  sio2681_$regs_t = [device] record
    unused_00: char;                      { 0x00 }
    mra: char;                            { 0x01: mode register (MR1,
                                            then MR2) }
    unused_02: char;
    sra_csra: char;                       { 0x03: read status, write clock
                                            select }
    unused_04: char;
    cra: char;                            { 0x05: command }
    unused_06: char;
    rhra_thra: char;                      { 0x07: receive / transmit
                                            holding }
    unused_08: char;
    ipcr_acr: char;                       { 0x09: read input port change,
                                            write auxiliary control }
    unused_0a: char;
    isr_imr: char;                        { 0x0B: read interrupt status,
                                            write interrupt mask }
    unused_0c: char;
    ctu_ctur: char;                       { 0x0D }
    unused_0e: char;
    ctl_ctlr: char;                       { 0x0F }
    unused_10: char;                      { 0x10: channel B's half }
    mrb: char;                            { 0x11 }
    unused_12: char;
    srb_csrb: char;                       { 0x13 }
    unused_14: char;
    crb: char;                            { 0x15 }
    unused_16: char;
    rhrb_thrb: char;                      { 0x17 }
    unused_18: char;
    ivr: char;                            { 0x19 }
    unused_1a: char;
    ipr_opcr: char;                       { 0x1B: read input port, write
                                            output port configuration }
    unused_1c: char;
    sopbc: char;                          { 0x1D: set output port bits }
    unused_1e: char;
    ropbc: char;                          { 0x1F: reset output port bits }
  end;
  sio2681_$regs_ptr_t = ^sio2681_$regs_t;

  { The members of an 8-bit interrupt status or mask (0 TxRDY A, 1 RxRDY
    A, 4 TxRDY B, 5 RxRDY B, 7 input change). }
  sio2681_$bits_t = set of 0..7;

  { A byte of interrupt bits as a packed record (ref 3.10.7: the 8-bit
    set at the record's first byte, member k its bit k; 16 bits in all):
    the chip's mask shadow and SIO2681_$INT's pending bits; the char arm
    for whole-byte moves and compares. }
  sio2681_$int_bits_t = packed record
    case integer of
      1: (c: char);                       { the byte }
      2: (s: sio2681_$bits_t);            { its members }
  end;

  { The input port bits (IPCR, and IPR's low four) as a packed record of
    booleans, the first at the most significant bit (ref 3.10.7): a
    frame word whose high byte is stored from the register, bits 15..8
    the register's bits 7..0. }
  sio2681_$ports_t = packed record
    case integer of
      1: (c: char);
      2: (delta_dcd_b: boolean;           { bit 15: IPCR bit 7 }
          delta_dcd_a: boolean;
          delta_cts_b: boolean;
          delta_cts_a: boolean;           { bit 12 }
          dcd_b: boolean;                 { bit 11: IP3 }
          dcd_a: boolean;                 { bit 10: IP2 }
          cts_b: boolean;                 { bit 9: IP1 }
          cts_a: boolean);                { bit 8: IP0 }
  end;

  { The chip's ACR shadow (config1, the high byte of the word at +4):
    set as a word from the configuration (SIO2681_$INIT), written to the
    register as its byte, its bit 7, the baud-rate set, a boolean field
    (sio2681_set_baud_rate, SIO2681_$SET_LINE). }
  sio2681_$acr_t = packed record
    case integer of
      1: (w: integer);
      2: (acr: char;                      { 0x00 }
          lo: char);                      { 0x01 }
      3: (extended: boolean);             { bit 15 }
  end;

  { The chip's output port shadow (config2, the high byte of the word at
    +6), written whole to SOPBC and complemented to ROPBC.  The names are
    the 2681's output port bits. }
  sio2681_$opr_t = packed record
    case integer of
      1: (w: integer);
      2: (opr: char;
          lo: char);
      3: (op7: boolean;                   { bit 15: the tone }
          op4_6: 0..7;
          op3: boolean;
          op2: boolean;
          op1: boolean;
          op0: boolean);                  { bit 8 }
  end;

  { The chip record, 0xC bytes. }
  sio2681_$chip_t = record
    regs: sio2681_$regs_ptr_t;            { 0x00 }
    config1: sio2681_$acr_t;              { 0x04 }
    config2: sio2681_$opr_t;              { 0x06 }
    imr_shadow: sio2681_$int_bits_t;      { 0x08: the IMR's copy (the
                                            register cannot be read) }
    reserved_0a: integer;                 { 0x0A }
  end;
  sio2681_$chip_ptr_t = ^sio2681_$chip_t;

  { The channel's flag word: a word set, set and cleared whole by
    SIO2681_$INIT, members tested and cleared on the byte: member 1
    channel A, member 0 cleared by every SIO2681_$SET_LINE. }
  sio2681_$chan_flags_t = set of 0..15;

  sio2681_$channel_ptr_t = ^sio2681_$channel_t;

  { The channel record, 0x1C bytes.  sio_desc is
    an SIO descriptor pointer (univ_ptr, as SIO_$I_RCV's parameter);
    reserved_14 is unioned into the parameter block's flags1
    (SIO2681_$INQ_LINE), a set as they are. }
  sio2681_$channel_t = record
    regs: sio2681_$regs_ptr_t;            { 0x00 }
    chip: sio2681_$chip_ptr_t;            { 0x04 }
    peer: sio2681_$channel_ptr_t;         { 0x08 }
    sio_desc: univ_ptr;                   { 0x0C }
    flags: integer;                       { 0x10: tested as a word }
    int_bit: integer;                     { 0x12: TxRDY's member, 0 or 4 }
    reserved_14: sio_$flags_t;            { 0x14 }
    chan_flags: sio2681_$chan_flags_t;    { 0x18 }
    baud_support: pinteger;               { 0x1A }
  end;

  { One SIO2681_$PTRS entry, 0x10 bytes:
    SIO2681_$INIT stores the three pointers, the hand-written stubs the
    interrupted pc, which SIO2681_$INT passes on by address. }
  sio2681_$ptrs_entry_t = record
    chan_a: sio2681_$channel_ptr_t;       { 0x00 }
    chan_b: sio2681_$channel_ptr_t;       { 0x04 }
    chip: sio2681_$chip_ptr_t;            { 0x08 }
    saved_pc: integer32;                  { 0x0C }
  end;

  { A transmit and a receive rate index, one longword:
    sio2681_set_baud_rate takes it by value and reads its two words;
    SIO2681_$SET_LINE compares them unsigned. }
  sio2681_$rates_t = record
    tx: pinteger;                         { 0x00 }
    rx: pinteger;                         { 0x02 }
  end;

  { The change mask of SIO2681_$SET_LINE and _$INQ_LINE, by value: a set,
    intersected with constant sets and its members tested in the
    register (member 7 as the low byte's sign): a set's forms.
    SIO2681_$INIT passes [0..13]. }
  sio2681_$mask_t = set of 0..31;

  { SIO2681_$INIT's configuration words (7 words, TERM's data); it reads
    the first and the third. }
  sio2681_$config_t = array[1..7] of integer;

var
  { SIO2681_$PTRS (map symbol; hand-written, in the SIO_INT data
    segment, sio2681/m68k/int_rte.s): one entry per chip, from 1. }
  sio2681_$ptrs: extern array[1..sio2681_max_chips] of sio2681_$ptrs_entry_t;

  { SIO_VEC (map symbol in TRAP_PAGE, the level-1 autovector; KEYBD_VEC
    after it, sio6509/sio6509.ins.pas), indexed from 1 by chip. }
  sio_vec: extern array[1..sio2681_max_chips] of univ_ptr;

{ SIO2681_$INT1_RTE, SIO2681_$INT2_RTE (hand-written, in SIO_INT,
  sio2681/m68k/int_rte.s): the interrupt entry points, no parameters. }
procedure sio2681_$int1_rte; extern;
procedure sio2681_$int2_rte; extern;

{ Routine headings, in map order.  The bodies repeat the full heading
  (ref 7.3.4, Method 2). }

{ SIO2681_$INT - service a 2681's interrupt. }
procedure sio2681_$int(in entry: sio2681_$ptrs_entry_t); extern;

{ SIO2681_$SET_BREAK - start or stop a break on a channel. }
procedure sio2681_$set_break(in channel: sio2681_$channel_t; enable: boolean);
  options(extern, val_param);

{ SIO2681_$TONE - switch the tone output of a channel's chip. }
procedure sio2681_$tone(in channel: univ_ptr; in enable: boolean;
                        out status_unused: status_$t); extern;

{ SIO2681_$SET_LINE - set a channel's line parameters. }
procedure sio2681_$set_line(var channel: sio2681_$channel_t;
                            in params: sio_$params_t;
                            change_mask: sio2681_$mask_t;
                            out status: status_$t);
  options(extern, val_param);

{ SIO2681_$XMIT - send a character on a channel. }
procedure sio2681_$xmit(in channel: sio2681_$channel_t; ch: char);
  options(extern, val_param);

{ SIO2681_$INIT - set up a 2681 and its two channels. }
procedure sio2681_$init(in int_vec: integer; in chip_num: integer;
                        var chan_a: sio2681_$channel_t;
                        in chan_a_callback: univ_ptr;
                        in chan_a_params: sio_$params_t;
                        var chan_b: sio2681_$channel_t;
                        in chan_b_callback: univ_ptr;
                        in chan_b_params: sio_$params_t;
                        var chip: sio2681_$chip_t;
                        in config: sio2681_$config_t); extern;

{ SIO2681_$INQ_LINE - report a channel's modem inputs. }
procedure sio2681_$inq_line(in channel: sio2681_$channel_t;
                            in out params: sio_$params_t;
                            mask: sio2681_$mask_t; out status: status_$t);
  options(extern, val_param);
