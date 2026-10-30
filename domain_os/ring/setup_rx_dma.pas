{ ring_$setup_rx_dma - program and start the two receive channels.

  Image addresses:
    sau2  0x00E758C4  ring_$setup_rx_dma (module-local)
    sau5  0x00E7CBCA  ring_$setup_rx_dma (module-local)

  - Channel 0 receives into the header buffer and channel 1 into the
    data buffer, 512 words each.
  - A controller that moves its packets itself (`ring_controller_dma')
    gets the counts and addresses in its registers.

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
