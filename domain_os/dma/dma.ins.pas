{ dma/dma.ins.pas - DMA_ (the MC68450 DMA controller) types, variables and
  routine headings, for the Domain Pascal tree.

  One channel's registers, the controller's page DMA and the three
  map-global routines; the module is dma/dma.pas.  No customer insert
  file declares these.  Include base/base.ins.pas before it.
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

var
  { DMA (map symbol without `$', IODEFS): the controller's four
    channels, 0x40 bytes apart, from 0. }
  dma: extern array[0..3] of dma_$m68450_channel_t;

{ Routine headings, in map order (the map's DMA_ segment, WIRED_PROC).
  The bodies repeat the full heading (ref 7.3.4, Method 2). }

{ DMA_$INIT - put the four DMA channels into their idle state. }
procedure dma_$init; extern;

{ DMA_$CHECK - read and clear a DMA channel's completion state. }
function dma_$check(channel: integer): integer32;
  options(extern, val_param);

{ DMA_$FREE_ASID - free an address space's DMA state (nothing to do). }
procedure dma_$free_asid(asid: integer); options(extern, val_param);
