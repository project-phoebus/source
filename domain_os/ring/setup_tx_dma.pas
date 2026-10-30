{ ring_$setup_tx_dma - program the transmit channel.

  Image addresses:
    sau2  0x00E7584E  ring_$setup_tx_dma (module-local)
    sau5  0x00E7CB60  ring_$setup_tx_dma (module-local)

  - Channel 2 is given the header and, with data, the data as its
    chained second block, and started.
  - A controller that moves its packets itself (`ring_controller_dma')
    gets the header's and the data's counts and addresses in its
    registers; without data the header's count carries 16#800.  The
    caller starts the transmitter.

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
