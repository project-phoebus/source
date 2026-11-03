{ iic_stop - stop a line: tell the other end, reset the controller and
  give the line's resources back.

  Image addresses:
    sau3  0x00E71396  iic_stop (module-local)

  - The guardian's stop request.  The transmit pages, the socket, the
    I/O map space, the command block's page and the receive buffers are
    released; the last line stopped sets the PBU unit down.
  - A failure to free the I/O map space ends it there.

  Status stored:
    status_$ok: after the reset
    pbu_$free's status: the I/O map space was not freed
    iic_release_pbu's status: the last line was stopped
}

procedure iic_stop(line: pinteger; out status: status_$t); internal;
begin
  iic_send_link(line, iic_link_down, status);
  with iic_lines[line] do begin
    csr^.control := iic_csr_reset;
    time_$wait(time_$relative, iic_stop_wait, status);
    csr^.control := 0;
    status.all := status_$ok;

    mmu_$remove(rshft(tx_hdr_pa, 10));
    mmap_$free(rshft(tx_hdr_pa, 10));
    mmu_$remove(rshft(tx_data_pa, 10));
    mmap_$free(rshft(tx_data_pa, 10));
    sock_$close(sock);

    if pbu_allocated then begin
      pbu_$free(iic_pbu_unit, iova, 5, status);
      if status.all <> status_$ok then
        return;
    end;
    if pages_mapped then begin
      mmu_$remove(cb_ppn);
      mmap_$free(cb_ppn);
    end;
    if bufs_allocated then begin
      netbuf_$rtn_hdr(rx_hdr_va);
      netbuf_$rtn_dat(rx_data_pa);
    end;

    iic_users := iic_users - 1;
    if iic_users = 0 then
      iic_release_pbu(status);
  end;
end;
