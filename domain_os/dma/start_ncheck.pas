{ DMA_$START_NCHECK - start a DMA transfer for a physical address.

  Image addresses:
    sau8  0x03C0AD98  DMA_$START_NCHECK

  - The channel is taken for the current address space under the DMA
    lock, then programmed under it again: single mode, the direction
    (0 a write to memory, else a read from it), the mode's members
    (auto-initialize, address decrement, cascade), the address and the
    page, the count less one, and the channel unmasked.
  - Channels 4..7 are the second controller's: their address register
    takes the address in words, their page register the address's bits
    16..23.
  - The channel is not checked: a caller gives 0..7.

  Status stored:
    status_$ok: the transfer was started
    status_$dma_channel_in_use: the channel is taken
}

[section(wired_proc, wired_data)]
procedure dma_$start_ncheck(channel: integer; count: integer;
                            pa: integer32; direction: integer;
                            mode: integer; out status: status_$t);
  options(val_param);
var
  token: pinteger;
  mode_byte: integer;
  a: integer32;
  page: dma_$byte_t;
  word_addr: integer32;
begin
  token := ml_$spin_lock(dma_lock);
  if dma_owner[channel] <> dma_free then begin
    status.all := status_$dma_channel_in_use;
    ml_$spin_unlock(dma_lock, token);
    return;
  end;
  dma_owner[channel] := proc1_$as_id;
  ml_$spin_unlock(dma_lock, token);
  status.all := status_$ok;

  { The mode register's value. }
  mode_byte := (channel & 3) ! dma_mode_single;
  if direction = 0 then
    mode_byte := mode_byte ! dma_mode_write
  else
    mode_byte := mode_byte ! dma_mode_read;
  if 0 in dma_$mode_t(mode) then
    mode_byte := mode_byte ! dma_mode_autoinit;
  if 1 in dma_$mode_t(mode) then
    mode_byte := mode_byte ! dma_mode_decrement;
  if 2 in dma_$mode_t(mode) then
    mode_byte := mode_byte ! dma_mode_cascade;

  a := pa;
  token := ml_$spin_lock(dma_lock);
  if channel < 4 then begin
    dma.clear_ff1 := 0;
    dma.chan[channel].addr := a;
    dma.chan[channel].addr := rshft(a, 8);
    a := rshft(a, 16);
    page := a;
    case channel of
      0: dma.page0 := page;
      1: dma.page1 := page;
      2: dma.page2 := page;
      3: dma.page3 := page;
    end;
    dma.clear_ff1 := 0;
    dma.chan[channel].count := count - 1;
    dma.chan[channel].count := rshft(count - 1, 8);
    dma.mode1 := mode_byte;
    dma.mask1 := mode_byte & 3;
  end
  else begin
    dma.clear_ff2 := 0;
    word_addr := rshft(a, 1);
    dma.chan2[channel].addr := word_addr;
    dma.chan2[channel].addr := rshft(word_addr, 8);
    a := rshft(a, 16);
    page := a;
    case channel of
      5: dma.page5 := page;
      6: dma.page6 := page;
      7: dma.page7 := page;
    end;
    dma.clear_ff2 := 0;
    dma.chan2[channel].count := count - 1;
    dma.chan2[channel].count := rshft(count - 1, 8);
    dma.mode2 := mode_byte;
    dma.mask2 := mode_byte & 3;
  end;
  ml_$spin_unlock(dma_lock, token);
end;
