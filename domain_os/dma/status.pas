{ DMA_$STATUS - whether a DMA channel's transfer has finished.

  Image addresses:
    sau8  0x03C0B048  DMA_$STATUS

  - Under the DMA lock: the channel's controller status joins the
    terminal counts seen (dma_done), and a terminal count of the
    channel is taken (cleared) as the transfer's end.  The channel stays
    taken.

  Status stored:
    status_$ok: the transfer has finished
    status_$dma_illegal_channel: channel is not 0..7
    status_$dma_channel_not_allocated: the channel is not taken
    status_$dma_did_not_finish: no terminal count for the channel yet
}

[section(wired_proc, wired_data)]
procedure dma_$status(channel: integer; out status: status_$t);
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
    if channel < 4 then
      n := dma.cmd_status1
    else
      n := lshft(dma.cmd_status2, 4);
    dma_done := dma_done ! n;
    if (dma_done & lshft(1, channel)) <> 0 then begin
      status.all := status_$ok;
      dma_done := dma_done - lshft(1, channel);
    end
    else
      status.all := status_$dma_did_not_finish;
  end;
  ml_$spin_unlock(dma_lock, token);
end;
