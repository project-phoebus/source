{ DMA_$STOP - stop a DMA channel and free it.

  Image addresses:
    sau7  0x3C40B826  DMA_$STOP
    sau8  0x03C0AF4A  DMA_$STOP

  - Under the DMA lock: the channel's controller status joins the
    terminal counts seen (dma_done, the second controller's shifted to
    bits 4..11), the channel is masked, and residue is its count
    register plus one (doubled for channels 4..7: bytes).  The count is
    read low byte, then high byte, without clearing the byte pointer
    first.
  - The transfer finished when the channel's terminal count was seen,
    which is then cleared.
  - With `atbus_dma_iomap' a channel enabled for cascade is disabled in
    the master enable register instead, and the routine returns with
    the DMA lock held; the CPU status register's word is read into
    dma_io_wait after each of the controllers' accesses.

  Status stored:
    status_$ok: the transfer had finished
    status_$dma_illegal_channel: channel is not 0..7
    status_$dma_channel_not_allocated: the channel is not taken
    status_$dma_did_not_finish: no terminal count for the channel
}

%if atbus_dma_iomap %then
[section(wired_proc, wired_data)]
procedure dma_$stop(channel: integer; out residue: integer32;
                    out status: status_$t);
  options(val_param);
var
  token: pinteger;
  bit: integer;
  n: integer;
begin
  if (channel < 0) or else (channel > 7) then begin
    status.all := status_$dma_illegal_channel;
    return;
  end;
  token := ml_$spin_lock(dma_lock);
  if dma_owner[channel] = dma_free then
    status.all := status_$dma_channel_not_allocated
  else begin
    dma_owner[channel] := dma_free;

    { A cascade channel: disabled in the master enable register. }
    if channel > 4 then
      bit := channel - 1
    else
      bit := channel;
    if bit in dma_cascade then begin
      dma_cascade := dma_cascade - [bit];
      mast_enbl_reg.enable := dma_cascade;
      status.all := status_$ok;
      return;
    end;

    if channel < 4 then begin
      dma_done := dma_done ! dma.cmd_status1;
      dma_io_wait := mmu.csr;
      dma.mask1 := dma_mask_set ! channel;
      dma_io_wait := mmu.csr;
      n := dma.chan[channel].count;
      dma_io_wait := mmu.csr;
      n := n + lshft(dma.chan[channel].count, 8) + 1;
      dma_io_wait := mmu.csr;
    end
    else begin
      dma_done := dma_done ! lshft(dma.cmd_status2, 4);
      dma_io_wait := mmu.csr;
      dma.mask2 := (channel & 3) ! dma_mask_set;
      dma_io_wait := mmu.csr;
      n := dma.chan2[channel].count;
      dma_io_wait := mmu.csr;
      n := (n + lshft(dma.chan2[channel].count, 8) + 1) * 2;
      dma_io_wait := mmu.csr;
    end;
    residue := n;
    if (dma_done & lshft(1, channel)) <> 0 then begin
      status.all := status_$ok;
      dma_done := dma_done - lshft(1, channel);
    end
    else
      status.all := status_$dma_did_not_finish;
  end;
  ml_$spin_unlock(dma_lock, token);
end;
%else
[section(wired_proc, wired_data)]
procedure dma_$stop(channel: integer; out residue: integer32;
                    out status: status_$t);
  options(val_param);
var
  token: pinteger;
  n: integer;
begin
  if (channel < 0) or else (channel > 7) then begin
    status.all := status_$dma_illegal_channel;
    return;
  end;
  token := ml_$spin_lock(dma_lock);
  if dma_owner[channel] = dma_free then
    status.all := status_$dma_channel_not_allocated
  else begin
    dma_owner[channel] := dma_free;
    if channel < 4 then begin
      dma_done := dma_done ! dma.cmd_status1;
      dma.mask1 := dma_mask_set ! channel;
      n := dma.chan[channel].count + lshft(dma.chan[channel].count, 8) + 1;
    end
    else begin
      dma_done := dma_done ! lshft(dma.cmd_status2, 4);
      dma.mask2 := (channel & 3) ! dma_mask_set;
      n := (dma.chan2[channel].count +
            lshft(dma.chan2[channel].count, 8) + 1) * 2;
    end;
    residue := n;
    if (dma_done & lshft(1, channel)) <> 0 then begin
      status.all := status_$ok;
      dma_done := dma_done - lshft(1, channel);
    end
    else
      status.all := status_$dma_did_not_finish;
  end;
  ml_$spin_unlock(dma_lock, token);
end;
%endif
