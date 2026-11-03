{ DMA_$STOP - stop a DMA channel and free it.

  Image addresses:
    sau8  0x03C0AF4A  DMA_$STOP

  - Under the DMA lock: the channel's controller status joins the
    terminal counts seen (dma_done, the second controller's shifted to
    bits 4..11), the channel is masked, and residue is its count
    register plus one (doubled for channels 4..7: bytes).  The count is
    read low byte, then high byte, without clearing the byte pointer
    first.
  - The transfer finished when the channel's terminal count was seen,
    which is then cleared.

  Status stored:
    status_$ok: the transfer had finished
    status_$dma_illegal_channel: channel is not 0..7
    status_$dma_channel_not_allocated: the channel is not taken
    status_$dma_did_not_finish: no terminal count for the channel
}

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
