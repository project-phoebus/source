{ scsi_finish_data - account for a data transfer that has stopped.

  Image addresses:
    sau9  0x3C4A61FE  scsi_finish_data

  Assume we're called with the SCSI spin lock held.

  - The request's buffer offset and length move by the bytes moved; on
    a transfer out, the bytes still in the FIFO are taken back and the
    FIFO is flushed.
  - A padded request (underrun, wrong direction) only has the FIFO
    flushed.
}

procedure scsi_finish_data(cb: scsi_cb_ptr_t; req: scsi_req_ptr_t);
var
  left: scsi_count_t;
  regs: c90_regs_ptr_t;
  n: pinteger;
begin
  left.all := 0;
  if (req^.result.status.all = status_$scsi_dma_underrun)
     or else (req^.result.status.all = status_$scsi_illegal_data_direction) then
    cb^.regs^.cmd := c90_cmd_flush_fifo
  else if (req^.length <> 0) and then cb^.dma_active then begin
    regs := cb^.regs;
    cb^.dma_active := false;
    n := cb^.dma_count;
    req^.offset := req^.offset + (req^.length - n);
    req^.length := n;
    if req^.dir = scsi_$dir_out then begin
      left.bits.fifo_count := regs^.r1c.fifo_flags.count;
      req^.offset := req^.offset - left.lo;
      req^.length := req^.length + left.lo;
      regs^.cmd := c90_cmd_flush_fifo;
    end;
    cb^.dma_count := req^.length;
  end;
end;
