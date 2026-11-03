{ read_or_write_disk_record - start the data transfer of the current
  request.

  Image addresses:
    sau2  0x00E19414  read_or_write_disk_record (module-local)
    sau4  0x0F819D16  read_or_write_disk_record (module-local)

  - DMA channel 3 is programmed for the request (16 and 512 the
    transfer counts, the direction from its operation, counted in
    WIN_$CNT) and started, then the drive: the sector, mode 9, go.
  - The ring/disk form maps the request's header and data pages at the
    Winchester's I/O map entries, programs the board's two DMA channels
    (at IPL 7), selects the drive, head and sector on either interface
    and starts the transfer with the interrupt enabled.

  Returns:
    status_$ok: the transfer was started (always, but the ring/disk
      form's write protection)
    status_$disk_write_protected: a write to a protected drive (the
      ring/disk form)

  Status stored: none.
}

%if win_ring_disk_ctlr %then
function read_or_write_disk_record(in vol: disk_$volume_t;
                                   in req: disk_$io_req_t): integer32;
  internal;
var
  regs: win_$regs_ptr_t;
  writing: boolean;
  head: pinteger;
  old_sr: integer;
  offset: pinteger;
  sel: pinteger;
begin
  regs := win_units[0].regs;
  writing := req.owner_op.op = disk_$req_op_write;
  head := req.daddr.head;

  { the block header's page and the data page in the I/O map }
  win_hdr_iomap^ := rshft(req.phys, 10);
  win_data_iomap^ := req.ppn;

  { the DMA channels, at IPL 7: the header's 16 words from its offset in
    the first page, the data page's 512 words }
  old_sr := set_sr(16#2700);
  regs^.dma_clear_ptr := 0;
  offset := rshft(req.phys & 16#3FF, 1);
  regs^.dma_addr0 := offset;
  regs^.dma_addr0 := rshft(offset, 8) + 16#80;
  regs^.dma_addr1 := 0;
  regs^.dma_addr1 := 16#82;
  regs^.dma_count0 := 16#0F;
  regs^.dma_count0 := 0;
  regs^.dma_count1 := 16#FF;
  regs^.dma_count1 := 1;
  discard(set_sr(old_sr));
  regs^.dma_mask := 16#10;
  regs^.dma_mask := 16#11;

  if win_smd_interface in win_units[0].unit_bits then begin
    { the SMD interface: the drive and head, the cylinder's high bits and
      the sector }
    sel := (lshft(vol.dev_unit, 4) & 16#70) ! (15 - (head & 15));
    regs^.select := sel ! 16#80;
    regs^.head := 0;
    regs^.select := sel;
    regs^.head := head;
    regs^.cmd := 5;
    regs^.cyl_hi := (head & 16#F0) ! (rshft(req.daddr.cyl, 8) & 3);
    regs^.sector := req.daddr.sector;
    regs^.select := sel ! 16#80;
    regs^.head := 0;
    regs^.select := sel;
    regs^.head := 0;
    regs^.cmd := 1;
    if writing and then (4 in regs^.status) then begin
      read_or_write_disk_record := status_$disk_write_protected;
      return;
    end;
    regs^.cmd := 3;
  end
  else begin
    { the PRIAM interface: the drive and head, the sector }
    regs^.select := 255 - (lshft(16, vol.dev_unit) + head);
    if writing and then (win_st_write_protect in regs^.status) then begin
      read_or_write_disk_record := status_$disk_write_protected;
      return;
    end;
    regs^.sector := req.daddr.sector;
  end;

  { the direction, and the start }
  if writing then begin
    win_$cnt.xfer_op2 := win_$cnt.xfer_op2 + 1;
    regs^.dma_mode := 8;
    regs^.dma_mode := 9;
    regs^.control := win_ctl_write;
  end
  else begin
    win_$cnt.xfer_other := win_$cnt.xfer_other + 1;
    regs^.dma_mode := 4;
    regs^.dma_mode := 5;
    regs^.control := win_ctl_read;
  end;
  read_or_write_disk_record := status_$ok;
end;
%else

{ TODO(pascal) eight frame bytes in read_or_write_disk_record

  In the SAU2 frame the reserved slot (4), regs (4), req (4), go (2, and
  2 of alignment) and the 4-byte result variable explain 20 of 28 bytes;
  nothing in the routine addresses the frame.  The stand-in unused_10
  holds the other 8, as in win_$ansi_command (8 bytes there too); what
  they were is not known. }

function read_or_write_disk_record(unit: pinteger): integer32; internal;
var
  regs: win_$regs_ptr_t;
  req: disk_$io_req_ptr_t;
  go: win_$byte_t;
  unused_10: array[1..2] of integer32;    { never addressed: the TODO }
begin
  regs := win_units[unit].regs;
  req := win_cur_req;

  { DMA channel 3 }
  dma[3].mtc := 16#10;
  dma[3].mar := req^.phys;
  dma[3].bar := lshft(req^.ppn, 10);
  dma[3].btc := 16#200;

  { the direction }
  if win_cur_req^.owner_op.op = disk_$req_op_write then begin
    dma[3].ocr := chr(16#12);
    go := 2;
    win_$cnt.xfer_op2 := win_$cnt.xfer_op2 + 1;
  end
  else begin
    dma[3].ocr := chr(16#92);
    go := 1;
    win_$cnt.xfer_other := win_$cnt.xfer_other + 1;
  end;

  { start the channel }
  dma[3].mfc := chr(0);
  dma[3].bfc := chr(1);
  dma[3].ccr := chr(16#C0);

  { and the drive }
  regs^.sector := req^.daddr.sector;
  regs^.mode := 9;
  regs^.go := go;

  read_or_write_disk_record := status_$ok;
end;
%endif
