{ scsi_start_dma - start a data phase's transfer.

  Image addresses:
    sau9  0x3C4A5EA0  scsi_start_dma

  Assume we're called with the SCSI spin lock held.

  - A request that maps its pages has them mapped at SCSI_PAGE first
    (physical addresses turned into page numbers); its pages go to the
    parity checks' DMA channel 0.
  - The controller moves the bytes through its DMA port, which
    SCSI_$C90_DMA serves.
  - A request with no bytes is padded, its status DMA underrun.
}

procedure scsi_start_dma(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                         req: scsi_req_ptr_t); internal;
var
  va: integer32;
  i: integer;
  ppn: integer32;
  count: scsi_count_t;
  ppns: scsi_page_list_t;
  regs: c90_regs_ptr_t;
begin
  if req^.length = 0 then begin
    req^.result.status.all := status_$scsi_dma_underrun;
    scsi_xfer_pad(cb, tgt, req);
    return;
  end;
  if req^.mapped then begin
    va := integer32(addr(scsi_page));
    for i := 1 to req^.npages do begin
      if req^.ppn_list = false then
        ppn := rshft(req^.pages[i], 10)
      else
        ppn := req^.pages[i];
      mmu_$set_pmape(univ_ptr(va), cb^.pmape[i], ppn);
      ppns[i] := ppn;
      va := va + 1024;
    end;
    cb^.dma_buf := req^.offset + integer32(addr(scsi_page));
  end
  else
    cb^.dma_buf := req^.offset + req^.buf_va;
  parity_$set_state(0, ppns, req^.npages);
  cb^.dma_count := req^.length;
  cb^.dma_dir := req^.dir;
  cb^.dma_done := 0;
  cb^.dma_active := true;
  count.all := 0;
  count.lo := req^.length;
  regs := cb^.regs;
  regs^.r18.sync.period := tgt^.sync_period;
  regs^.r1c.sync.offset := tgt^.sync_offset;
  regs^.tc_lo := count.b3;
  regs^.tc_hi := count.b2;
  regs^.cmd := c90_cmd_dma_transfer_info;
  if req^.dir = scsi_$dir_out then
    tgt^.state := scsi_ts_data_out
  else
    tgt^.state := scsi_ts_data_in;
end;
