{ read_or_write_disk_record - start the data transfer of the current
  request.

  Image addresses:
    sau2  0x00E19414  read_or_write_disk_record (module-local)

  - DMA channel 3 is programmed for the request (16 and 512 the
    transfer counts, the direction from its operation, counted in
    WIN_$CNT) and started, then the drive: the sector, mode 9, go.

  Returns:
    status_$ok: always

  Status stored: none.
}

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
