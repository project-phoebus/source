{ dma/dma.ins.pas - DMA_ (the DMA controller) types, variables and
  routine headings, for the Domain Pascal tree.

  The MC68450's: one channel's registers, the controller's page DMA and
  the three map-global routines.  With the AT bus's DMA channels
  (`atbus_dma'): the two controllers' registers, the page DMA, the
  statuses and the six map-global routines.  The module is dma/dma.pas.
  No customer insert file declares these.  Include base/base.ins.pas
  before it.
}

const
  { MC68450 register values: CCR SAB, the software abort; CSR bits 4
    (ERR) and 3 (ACT). }
  m68450_ccr_sab = 16#10;
  m68450_csr_err = 16#10;
  m68450_csr_act = 16#08;

type
  { One MC68450 channel's registers, 0x40 bytes (the channels' stride),
    the MC68450's register names: the record of the conformance unit
    dma_init_m68450_channel.pas, `[device]' (ref 3.15.3).  The bytes no
    routine names are fillers (single chars where a word could not
    start, an array of chars being word aligned in a record, ref
    3.10.5.5).  MAR and MFC are FLP's, BTC, BAR and BFC WIN's (channel
    3). }
  dma_$m68450_channel_t = [device] record
    csr: char;                            { 0x00 channel status }
    cer: char;                            { 0x01 channel error }
    pad02, pad03: char;
    dcr: char;                            { 0x04 device control }
    ocr: char;                            { 0x05 operation control }
    scr: char;                            { 0x06 sequence control }
    ccr: char;                            { 0x07 channel control }
    pad08, pad09: char;
    mtc: integer;                         { 0x0A MTCH/MTCL, the memory
                                            transfer counter }
    mar: integer32;                       { 0x0C MARH..MARL, the memory
                                            address (for FLP) }
    pad10: array[16..25] of char;
    btc: integer;                         { 0x1A BTCH/BTCL, the base
                                            transfer counter (for WIN) }
    bar: integer32;                       { 0x1C BARH..BARL, the base
                                            address (for WIN) }
    pad20: array[32..40] of char;
    mfc: char;                            { 0x29 memory function code
                                            (for FLP) }
    pad2a, pad2b, pad2c: char;
    cpr: char;                            { 0x2D channel priority }
    pad2e: array[46..56] of char;
    bfc: char;                            { 0x39 base function code (for
                                            WIN) }
    pad3a: array[58..63] of char;
  end;
  dma_$m68450_channel_ptr_t = ^dma_$m68450_channel_t;

%if atbus_dma %then
  { The AT bus's two DMA controllers (8237s) as the I/O definitions map
    their ports: the first's 8-bit channels 0..3 from 0, the second's
    16-bit channels 4..7 from 16#100 (channel 4 cascades the first),
    the page registers from 16#201.  A channel's address and count
    registers take the low byte, then the high one (the byte pointer
    flip-flop cleared first).  cmd_status is the command register
    written, the status register read: the channels' terminal counts in
    bits 0..3, their requests in 4..7.  The mask register takes a
    channel's number with bit 2 set to mask it, clear to unmask it; the
    mode register a channel's number and its mode bits. }
  dma_$byte_t = [byte] 0..255;

  dma_$chan8_t = record
    addr: dma_$byte_t;                    { 0x00 }
    count: dma_$byte_t;                   { 0x01 }
  end;

  dma_$chan16_t = record
    addr: dma_$byte_t;                    { 0x00 }
    unused_01: dma_$byte_t;
    count: dma_$byte_t;                   { 0x02 }
    unused_03: dma_$byte_t;
  end;

  dma_$atbus_regs_t = [device] record
    chan: array[0..3] of dma_$chan8_t;    { 0x000 }
    cmd_status1: dma_$byte_t;             { 0x008 }
    unused_009: dma_$byte_t;
    mask1: dma_$byte_t;                   { 0x00A }
    mode1: dma_$byte_t;                   { 0x00B }
    clear_ff1: dma_$byte_t;               { 0x00C }
    master_clear1: dma_$byte_t;           { 0x00D }
    unused_00e: dma_$byte_t;
    all_mask1: dma_$byte_t;               { 0x00F }
    unused_010: array[16#010..16#0FF] of char;
    chan2: array[4..7] of dma_$chan16_t;  { 0x100 }
    cmd_status2: dma_$byte_t;             { 0x110 }
    unused_111: dma_$byte_t;
    unused_112: dma_$byte_t;
    unused_113: dma_$byte_t;
    mask2: dma_$byte_t;                   { 0x114 }
    unused_115: dma_$byte_t;
    mode2: dma_$byte_t;                   { 0x116 }
    unused_117: dma_$byte_t;
    clear_ff2: dma_$byte_t;               { 0x118 }
    unused_119: dma_$byte_t;
    master_clear2: dma_$byte_t;           { 0x11A }
    unused_11b: dma_$byte_t;
    unused_11c: dma_$byte_t;
    unused_11d: dma_$byte_t;
    all_mask2: dma_$byte_t;               { 0x11E }
    unused_11f: dma_$byte_t;
    unused_120: array[16#120..16#200] of char;
    page2: dma_$byte_t;                   { 0x201 }
    page3: dma_$byte_t;                   { 0x202 }
    page1: dma_$byte_t;                   { 0x203 }
    unused_204: dma_$byte_t;
    unused_205: dma_$byte_t;
    unused_206: dma_$byte_t;
    page0: dma_$byte_t;                   { 0x207 }
    unused_208: dma_$byte_t;
    page6: dma_$byte_t;                   { 0x209 }
    page7: dma_$byte_t;                   { 0x20A }
    page5: dma_$byte_t;                   { 0x20B }
  end;

  { DMA_$START's and DMA_$START_NCHECK's mode word: member 0
    auto-initialize, 1 address decrement, 2 cascade. }
  dma_$mode_t = set of 0..15;
%endif

var
%if atbus_dma %then
  { DMA (map symbol without `$', IODEFS): the AT bus's DMA controllers. }
  dma: extern dma_$atbus_regs_t;
%else
  { DMA (map symbol without `$', IODEFS): the controller's four
    channels, 0x40 bytes apart, from 0. }
  dma: extern array[0..3] of dma_$m68450_channel_t;
%endif

{ Routine headings, in map order (the map's DMA_ segment, WIRED_PROC;
  with `atbus_dma' DMA_$INIT is the OS_INIT_PROC segment's).  The
  bodies repeat the full heading (ref 7.3.4, Method 2). }

{ DMA_$INIT - put the DMA channels into their idle state. }
procedure dma_$init; extern;

{ DMA_$CHECK - read and clear a DMA channel's completion state (the
  MC68450's; no AT bus SAU's map has it). }
function dma_$check(channel: integer): integer32;
  options(extern, val_param);

{ DMA_$FREE_ASID - free an address space's DMA state (nothing to do). }
procedure dma_$free_asid(asid: integer); options(extern, val_param);

%if atbus_dma %then
{ ---- The AT bus's DMA channels (`atbus_dma'). ---- }

const
  { The DMA manager's statuses, subsystem 16#2E, with the texts of the
    SR10.2 status-code database. }
  status_$dma_illegal_channel = 16#002E0001;      { "illegal channel" }
  status_$dma_illegal_byte_count = 16#002E0002;   { "illegal byte count" }
  status_$dma_channel_in_use = 16#002E0003;       { "channel in use" }
  status_$dma_channel_not_allocated = 16#002E0004;
                                        { "channel not allocated for
                                          operation" }
  status_$dma_did_not_finish = 16#002E0005;
                                        { "operation did not finish" }

  { A free channel's owner word (dma/dma.pas's dma_owner). }
  dma_free = -1;

  { The controllers' mode register bits (8237): single mode, a write to
    memory, a read from it, auto-initialize, address decrement,
    cascade; and the mask register's set bit. }
  dma_mode_single = 16#40;
  dma_mode_write = 16#04;
  dma_mode_read = 16#08;
  dma_mode_autoinit = 16#10;
  dma_mode_decrement = 16#20;
  dma_mode_cascade = 16#C0;
  dma_mask_set = 16#04;

{ DMA_$START - program a DMA channel for a transfer from a virtual
  address: the channel, the byte count (1..1024, within the address's
  page), the address, the direction and the mode, by value
  (`val_param'). }
procedure dma_$start(channel: integer; count: integer; va: integer32;
                     direction: integer; mode: integer;
                     out status: status_$t);
  options(extern, val_param);

{ DMA_$START_NCHECK - program a DMA channel for a transfer without
  checking its buffer: the channel, the byte count, the physical
  address, the direction (0 to memory, else from memory) and the mode
  flags (bit 0 auto-initialize, bit 1 address decrement, bit 2
  cascade); the channel must be free. }
procedure dma_$start_ncheck(channel: integer; count: integer;
                            pa: integer32; direction: integer;
                            mode: integer; out status: status_$t);
  options(extern, val_param);

{ DMA_$STOP - stop a DMA channel and free it, giving the count it had
  left. }
procedure dma_$stop(channel: integer; out residue: integer32;
                    out status: status_$t);
  options(extern, val_param);

{ DMA_$STATUS - a DMA channel's transfer's status.  The channel by value
  (`val_param'). }
procedure dma_$status(channel: integer; out status: status_$t);
  options(extern, val_param);
%endif
