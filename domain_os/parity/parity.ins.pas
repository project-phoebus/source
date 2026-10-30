{ parity/parity.ins.pas - PARITY (memory parity errors) types, variables
  and routine headings, for the Domain Pascal tree.

  The parity state PARITY_$INFO, the log entry PARITY_$CHK writes, the
  scratch page, the module's map-global variable and its routines; the
  module is parity/parity.pas.  With `parity_err_regs' the error
  registers PARITY_$CHK reads, with `parity_dma_pages' the DMA channel
  table and its routines' headings.

  Apollo's customer insert files of SR10.2 declare none of these
  (fault.ins.pas has only the fault status codes, fim/fim.ins.pas).
  Include base/base.ins.pas before it, and mmu/mmu.ins.pas without
  `parity_err_regs'.
}

const
  { The protection of the scratch page's temporary mapping ("Supervisor
    read/write"): PARITY_$CHK passes it to MMU_$INSTALL with ASID 0. }
  parity_scratch_prot = 16#16;

%if parity_dma_pages %then
  { The DMA channels PARITY_$DMA_TABLE has, and the pages one channel
    notes. }
  parity_dma_channels = 3;
  parity_dma_max_pages = 32;

%endif
type
  { A physical and a virtual address, 8 bytes, as one object: PARITY_$CHK
    copies PARITY_$INFO's pair into its log entry at once. }
  parity_$err_addrs_t = record
    pa: integer32;                        { 0x00 }
    va: integer32;                        { 0x04 }
  end;

%if parity_err_regs %then
  { The bus error status register MMU_BESR's byte, and its copy in
    PARITY_$INFO, as a 16-bit packed record (ref 3.10.7: the minimum
    size; the byte is bits 15..8).
    - 1, the whole byte, as PARITY_$CHK copies it.
    - 2, the four byte lanes of the failing longword, bit 10 the first
      (the lowest address): 1 when the lane had no parity error. }
  parity_$besr_t = packed record
    case integer of
      1: (all: 0..255;                    { bits 15..8 }
          bits_7_0: 0..255);              { bits 7..0 }
      2: (bits_15_14: 0..3;               { bits 15..14 }
          lane_3_ok: 0..1;                { bit 13 }
          lane_2_ok: 0..1;                { bit 12 }
          lane_1_ok: 0..1;                { bit 11 }
          lane_0_ok: 0..1;                { bit 10 }
          bits_9_0: 0..1023);             { bits 9..0 }
  end;

  { The register itself, `[device]' (ref 3.15.3). }
  parity_$besr_reg_t = [device] parity_$besr_t;

  { A parity error address register, MMU_PEARH or MMU_PEARL: a byte of
    the failing page's number. }
  parity_$pear_reg_t = [device] char;

  { PARITY_$INFO, 0x16 bytes from the map's PARITY_$INFO (its 0x14
    bytes, then the first word of MISS_STATUS, which err_data takes).
    - unused_10: nothing in the code reads or writes it.
    - err_status: MMU_BESR's copy.
    - err_data: the failing word of the scratch page, or the half of it
      the lane is in. }
  parity_$info_t = record
    spurious_count: integer;              { 0x00 }
    chk_in_progress: boolean;             { 0x02 }
    reserved_03: char;                    { 0x03 }
    err_ppn: integer32;                   { 0x04 }
    err: parity_$err_addrs_t;             { 0x08, 0x0C }
    unused_10: pinteger;                  { 0x10 }
    err_status: parity_$besr_t;           { 0x12 }
    err_data: pinteger;                   { 0x14 }
  end;

  { The entry PARITY_$CHK adds to the system log, 10 bytes: the status
    word at 0 and the two addresses at 2, word aligned (ref 3.10.5.5:
    objects longer than a byte on word boundaries in a record). }
  parity_$log_entry_t = record
    status: parity_$besr_t;               { 0x00 }
    addrs: parity_$err_addrs_t;           { 0x02: phys_addr, virt_addr }
  end;
%else
  { PARITY_$INFO, 0x14 bytes (the map's next symbol, MISS_STATUS, gives
    the size).
    - err_status: the hardware error word's copy (mmu/mmu.ins.pas
      mmu_$mem_err_word_t).
    - err_data: the failing word of the scratch page. }
  parity_$info_t = record
    spurious_count: integer;              { 0x00 }
    chk_in_progress: boolean;             { 0x02 }
    reserved_03: char;                    { 0x03 }
    err_ppn: integer32;                   { 0x04 }
    err: parity_$err_addrs_t;             { 0x08, 0x0C }
    err_status: mmu_$mem_err_word_t;      { 0x10 }
    err_data: pinteger;                   { 0x12 }
  end;

  { The entry PARITY_$CHK adds to the system log, 10 bytes: the status
    word at 0 and the two addresses at 2, word aligned (ref 3.10.5.5:
    objects longer than a byte on word boundaries in a record). }
  parity_$log_entry_t = record
    status: mmu_$mem_err_word_t;          { 0x00 }
    addrs: parity_$err_addrs_t;           { 0x02: phys_addr, virt_addr }
  end;
%endif

%if parity_dma_pages %then
  { The pages a channel's transfer uses, as PARITY_$SET_STATE takes
    them. }
  parity_$ppn_list_t = array[1..parity_dma_max_pages] of integer32;

  { One channel of PARITY_$DMA_TABLE, 0x84 bytes.
    - npages: how many of pages the transfer uses, 0 for none.
    - took_error: set by PARITY_$CHK when one of them took the error;
      PARITY_$CHK_IO reports and clears it. }
  parity_$dma_chan_t = record
    pages: parity_$ppn_list_t;            { 0x00 }
    npages: integer;                      { 0x80 }
    took_error: boolean;                  { 0x82 }
  end;

%endif
var
  { PARITY_$INFO (map symbol, inside the hand-written FIM's data segment
    FIM_WIRED: no compiled module defines it).  The hand-written
    FIM_$PARITY_TRAP (FIM_$NMI with `parity_err_regs') clears
    chk_in_progress and the byte after it after each call of
    PARITY_$CHK.  The map names it apart from FIM's other data, so it is
    a variable of its own here. }
  parity_$info: extern parity_$info_t;

%if parity_dma_pages %then
  { PARITY_$DMA_TABLE (map symbol, the only object of the PARITY data
    segment, WIRED_DATA, 0x18C bytes), defined in parity/parity.pas. }
  parity_$dma_table: extern array[0..parity_dma_channels - 1]
                       of parity_$dma_chan_t;
%else
  { PARITY_$DURING_DMA (map symbol, the only object of the PARITY data
    segment, WIRED_DATA), defined in parity/parity.pas. }
  parity_$during_dma: extern boolean;
%endif

  { PAR_BUFF (map symbol, IODEFS): the scratch page the failing frame is
    mapped at, 512 words (the 1 KB page the SAU1 scan reads). }
  par_buff: extern array[0..511] of pinteger;

%if parity_err_regs %then
  { MMU_BESR, MMU_PEARH, MMU_PEARL (map symbols of the I/O definitions,
    without `$'): the bus error status register and the failing page's
    number, its high and low byte. }
  mmu_besr: extern parity_$besr_reg_t;
  mmu_pearh: extern parity_$pear_reg_t;
  mmu_pearl: extern parity_$pear_reg_t;

%endif
{ Routine headings, in map order (PARITY, WIRED_PROC).  The bodies
  repeat the full heading (ref 7.3.4, Method 2). }

{ PARITY_$CHK - diagnose and log a memory parity error. }
function parity_$chk: boolean; extern;

%if parity_dma_pages %then
{ PARITY_$CHK_IO - tell an I/O driver whether its DMA channel's transfer
  took the parity error. }
function parity_$chk_io(channel: integer): integer;
  options(extern, val_param);

{ PARITY_$SET_STATE - note the pages a DMA channel's transfer uses. }
procedure parity_$set_state(channel: integer;
                            in ppns: univ parity_$ppn_list_t;
                            count: pinteger);
  options(extern, val_param);
%else
{ PARITY_$CHK_IO - tell an I/O driver whether its page took the DMA parity
  error. }
function parity_$chk_io(ppn1: integer32; ppn2: integer32): integer;
  options(extern, val_param);
%endif
