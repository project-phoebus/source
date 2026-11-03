{ ring_$setup_rx_dma - program and start the two receive channels.

  Image addresses:
    sau2  0x00E758C4  ring_$setup_rx_dma (module-local)
    sau4  0x0F8830EA  ring_$setup_rx_dma (module-local)
    sau5  0x00E7CBCA  ring_$setup_rx_dma (module-local)

  - Channel 0 receives into the header buffer and channel 1 into the
    data buffer, 512 words each.
  - A controller that moves its packets itself (`ring_controller_dma')
    gets the counts and addresses in its registers.
  - With the board's own DMA (`ring_board_dma') the receive's DMA
    controller is given the header on channel 0 and the data on channel
    1, 512 words each, at the I/O map's pages four and six on from the
    unit's page, which then maps the two buffers.

  Status stored: none.
}

%if ring_controller_dma %then
procedure ring_$setup_rx_dma(var regs: ring_$regs_t; hdr_pa: integer32;
                             data_pa: integer32);
  internal;
begin
  regs.rx_hdr_cnt := 512;
  regs.rx_hdr_addr := hdr_pa;
  regs.rx_data_cnt := 512;
  regs.rx_data_resid := 0;
  regs.rx_data_addr := data_pa;
end;
%elseif ring_board_dma %then
procedure ring_$setup_rx_dma(var dma: ring_$dma_t; page: integer;
                             hdr_pa: integer32; data_pa: integer32);
  internal;
begin
  dma.clear_ff := 0;
  dma.chan[0].addr := 0;
  dma.chan[0].addr := (page + 4) * 2;
  dma.chan[1].addr := 0;
  dma.chan[1].addr := (page + 6) * 2;
  dma.chan[0].count := 255;              { 511: 512 words less one }
  dma.chan[0].count := 1;
  dma.chan[1].count := 255;
  dma.chan[1].count := 1;
  dma.mode := 4;
  dma.mode := 5;
  dma.mask := 0;
  dma.mask := 1;
  iomap[page + 4] := rshft(hdr_pa, 10);
  iomap[page + 5] := 0;
  iomap[page + 6] := rshft(data_pa, 10);
  iomap[page + 7] := 0;
end;
%else
procedure ring_$setup_rx_dma(hdr_pa: integer32; data_pa: integer32);
  internal;
begin
  with dma[0] do begin
    mtc := 512;
    mar := hdr_pa;
    mfc := chr(0);
    with dma[1] do begin
      mtc := 512;
      mar := data_pa;
      mfc := chr(0);
      dma[0].ocr := chr(16#92);
      ocr := chr(16#92);
      dma[0].ccr := chr(16#80);
      ccr := chr(16#80);
    end;
  end;
end;
%endif
