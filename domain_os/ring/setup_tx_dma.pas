{ ring_$setup_tx_dma - program the transmit channel.

  Image addresses:
    sau2  0x00E7584E  ring_$setup_tx_dma (module-local)
    sau4  0x0F883006  ring_$setup_tx_dma (module-local)
    sau5  0x00E7CB60  ring_$setup_tx_dma (module-local)

  - Channel 2 is given the header and, with data, the data as its
    chained second block, and started.
  - A controller that moves its packets itself (`ring_controller_dma')
    gets the header's and the data's counts and addresses in its
    registers; without data the header's count carries 16#800.  The
    caller starts the transmitter.
  - With the board's own DMA (`ring_board_dma') the transmit's DMA
    controller is given the header on channel 2 and the data on channel
    3, at interrupt level 7, each at a page of the I/O map from the
    unit's page, which then maps the two buffers.

  Status stored: none.
}

%if ring_controller_dma %then
procedure ring_$setup_tx_dma(var regs: ring_$regs_t; hdr_pa: integer32;
                             hdr_len: integer; data_pa: integer32;
                             data_len: integer);
  internal;
begin
  if data_len <> 0 then
    regs.tx_hdr_cnt := (hdr_len + 1) div 2
  else begin
    regs.tx_hdr_cnt := (hdr_len + 1) div 2 + 16#800;
    regs.tx_data_resid := 0;
  end;
  regs.tx_hdr_addr := hdr_pa;
  regs.tx_data_cnt := (data_len + 1) div 2;
  regs.tx_data_addr := data_pa;
end;
%elseif ring_board_dma %then
procedure ring_$setup_tx_dma(var dma: ring_$dma_t; page: integer;
                             hdr_pa: integer32; hdr_len: pinteger;
                             data_pa: integer32; data_len: pinteger);
  internal;
var
  cnt: pinteger;
begin
  disable;
  dma.clear_ff := 0;

  { channel 2: the header, at the unit's first page }
  dma.chan[2].addr := 0;
  dma.chan[2].addr := page * 2;
  cnt := rshft((hdr_len - 1) & 16#FFFF, 1);   { as a word: 0 gives 16#7FFF }
  dma.chan[2].count := cnt;
  dma.chan[2].count := rshft(cnt, 8);
  dma.mode := 16#0A;
  dma.mask := 2;

  { channel 3: the data, two pages on }
  dma.chan[3].addr := 0;
  dma.chan[3].addr := (page + 2) * 2;
  cnt := rshft((data_len - 1) & 16#FFFF, 1);
  dma.chan[3].count := cnt;
  dma.chan[3].count := rshft(cnt, 8);
  dma.mode := 16#0B;
  dma.mask := 3;
  enable;

  { the two pages in the I/O map }
  iomap[page] := rshft(hdr_pa, 10);
  iomap[page + 1] := 0;
  iomap[page + 2] := rshft(data_pa, 10);
  iomap[page + 3] := 0;
end;
%else
procedure ring_$setup_tx_dma(hdr_pa: integer32; hdr_len: integer;
                             data_pa: integer32; data_len: integer);
  internal;
begin
  with dma[2] do begin
    mtc := (hdr_len + 1) div 2;
    mar := hdr_pa;
    ocr := chr(16#12);
    if data_len = 0 then begin
      mfc := chr(0);
      ccr := chr(16#80);
    end
    else begin
      btc := (data_len + 1) div 2;
      bar := data_pa;
      mfc := chr(2);
      bfc := chr(1);
      ccr := chr(16#C0);
    end;
  end;
end;
%endif
