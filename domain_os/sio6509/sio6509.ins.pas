{ sio6509/sio6509.ins.pas - SIO6509_ (the 6509 console serial
  controller driver) types, variables and routine headings, for the
  Domain Pascal tree.

  The channel record, the chip's register block, the hand-written
  objects, the trap and register pages SIO6509_$INIT writes, and the
  five compiled routines' headings (fragments of the SIO_IO module).
  Include base/base.ins.pas and sio/sio.ins.pas before it.
}

const
  { The entries of SIO6509_$PTRS: four longwords, the hand-written
    SIO6509_$INT1_RTE following them (sio6509/m68k/int1_rte.s). }
  sio6509_ptrs_count = 4;

  { The 32-byte register blocks of the map's SIO page (0x400 bytes to
    the next symbol, MMU): 0x400 / 0x20 = 32.  The image indexes only by
    the chip number (sio6509/init.pas). }
  sio6509_sio_blocks = 32;

type
  { One chip's register block, 0x20 bytes (the stride SIO6509_$INIT
    indexes by).  SIO6509_$INIT writes the two configuration bytes to
    +1, SIO6509_$RCV reads the status byte at +1 and the received
    character at +3.  Bytes, which a record packs (ref 3.10.5.5).   ctrl is
    the control register, data the received
    character's register. }
  sio6509_$regs_t = record
    unused_0: char;                       { 0x00 }
    ctrl: char;                           { 0x01: written: configuration;
                                            read: status }
    unused_2: char;                       { 0x02 }
    data: char;                           { 0x03 }
    unused_4: array[4..31] of char;       { 0x04 }
  end;
  sio6509_$regs_ptr_t = ^sio6509_$regs_t;

  { The channel record, 8 bytes: TERM_$INIT passes
    TERM's block + 0x1250.  SIO6509_$INIT stores the register block's
    address and the SIO descriptor's; SIO6509_$RCV reads both.  sio_desc
    is a pointer to an SIO descriptor, which has no Pascal type yet:
    univ_ptr, as SIO_$I_RCV's parameter. }
  sio6509_$chan_t = record
    regs: sio6509_$regs_ptr_t;            { 0x00 }
    sio_desc: univ_ptr;                   { 0x04 }
  end;

  { The two configuration bytes SIO6509_$INIT writes in turn, from 1.
    TERM_$INIT passes its block's bytes 16#03, 16#D9 at +0x5A. }
  sio6509_$config_t = array[1..2] of char;

var
  { SIO6509_$PTRS (map symbol; hand-written, in the map's SIO_INT data
    segment, sio6509/m68k/int1_rte.s): the channel record's address per
    interrupt vector, from 1.  SIO6509_$INIT stores element vec, the
    symbol as the base, the lower bound 1 folded into the displacement.
    univ_ptr: the stub loads element 1 and pushes it. }
  sio6509_$ptrs: extern array[1..sio6509_ptrs_count] of univ_ptr;

  { KEYBD_VEC 0x68 (map symbol in the trap page TRAP_PAGE, the exception
    vector table; SIO_VEC 0x64 before it, RING_VEC 0x6C after):
    SIO6509_$INIT stores the handler's address into element vec, the
    symbol as the base and the lower bound 1 folded in, as for
    SIO6509_$PTRS (vector 1 is KEYBD_VEC itself, the level-2 autovector,
    vector 26).  The bound is SIO6509_$PTRS's (0x68..0x77, KEYBD_VEC
    through DISK_VEC's 0x74; nothing else of the image indexes it).  No
    insert file of the tree declares the trap page; it is declared here,
    where it is used, under the map's name. }
  keybd_vec: extern array[1..sio6509_ptrs_count] of univ_ptr;

  { SIO (map symbol, the serial I/O register page, a SAU2 hardware
    address): 32 register blocks, from 1.  SIO6509_$INIT forms the
    address of block chip: the symbol as the base, the lower bound 1
    folded into the displacement. }
  sio: extern array[1..sio6509_sio_blocks] of sio6509_$regs_t;

{ SIO6509_$INT1_RTE (map symbol; hand-written, in the map's SIO_INT data
  segment, sio6509/m68k/int1_rte.s): the interrupt entry.  No compiled
  code calls it; SIO6509_$INIT stores its address in the vector,
  addr(sio6509_$int1_rte).
  No parameters. }
procedure sio6509_$int1_rte; extern;

{ Routine headings, in map order.  The bodies repeat the full heading
  (ref 7.3.4, Method 2).  The routines are SIO_IO's, in three of its
  code segments (sio6509/README.md). }

{ SIO6509_$RCV - hand a received character to the SIO line. }
procedure sio6509_$rcv(in chan: sio6509_$chan_t); extern;

{ SIO6509_$XMIT - the console line's transmit entry: an empty procedure. }
procedure sio6509_$xmit(in chan: sio6509_$chan_t; ch: char);
  options(extern, val_param);

{ SIO6509_$INIT - set up a 6509 console serial channel. }
procedure sio6509_$init(in vec: integer; in chip: integer;
                        var chan: sio6509_$chan_t; in callback: univ_ptr;
                        in config: sio6509_$config_t); extern;

{ SIO6509_$SET_LINE - the console line's set-line entry: always
  "invalid option". }
procedure sio6509_$set_line(in chan: sio6509_$chan_t; in params: sio_$params_t;
                            change_mask: integer32; out status: status_$t);
  options(extern, val_param);

{ SIO6509_$INQ_LINE - the console line's inquire-line entry. }
procedure sio6509_$inq_line(in chan: sio6509_$chan_t; in out params: sio_$params_t;
                            mask: integer32; out status: status_$t);
  options(extern, val_param);
