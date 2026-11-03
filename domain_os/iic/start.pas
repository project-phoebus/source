{ iic_start - start a line: set its resources up, reset and initialize
  the controller, and tell the other end.

  Image addresses:
    sau3  0x00E714BE  iic_start (module-local)

  - The guardian's start request.  The first line started sets the PBU
    unit up.  The line's I/O map space has five pages: the command
    block, the two receive buffers (a network header and a data buffer)
    and the two transmit pages; the command block and the transmit pages
    are new wired pages mapped at the line's control pages.
  - The reset is polled for up to 1000 times 2 ms.  The board must be
    revision 21 or later, or 00, of kind AC.
  - A self test failure the reset reports is the status when nothing
    else failed: the line is up all the same.

  Status stored:
    iic_setup_pbu's status: the PBU unit was not set up
    status_$iic_device_not_in_system: the line's register does not
      answer
    pbu_$get_ptr's, pbu_$alloc's, wp_$calloc's status
    status_$iic_no_receive_socket: no socket for the line
    time_$wait's status
    status_$iic_reset_timed_out: the reset did not end
    iic_command's status: the initialization or the receive setup failed
    status_$iic_wrong_board_revision: the board's revision is not one of
      these
    iic_send_link's status
    status_$iic_self_test_failure: the reset reported a failed self test
}

procedure iic_start(line: pinteger; out status: status_$t); internal;
var
  data: integer;
  iova_bytes: iic_$long_bytes_t;
  regs: iic_$csr_ptr_t;
  size: integer32;
  cb: iic_$page_ptr_t;
  hdr_ppn: integer32;
  data_ppn: integer32;
  tries: integer;
  i: integer;
  self_test_failed: boolean;
begin
  if iic_users = 0 then begin
    iic_setup_pbu(status);
    if status.all <> status_$ok then
      return;
  end;
  iic_users := iic_users + 1;

  with iic_lines[line] do begin
    next_send.high := 0;
    next_send.low := 0;
    regs := addr(pbu_iic_page[line]);
    present := testpage(0, regs, data);
    if not present then begin
      status.all := status_$iic_device_not_in_system;
      return;
    end;
    csr := regs;
    int_ec_ptr := addr(pbu_$dcte_ptr_t(
                       pbu_$get_ptr(iic_pbu_unit, pbu_ptr_dcte, size,
                                    status))^.ec_ptr);
    pbu_allocated := false;
    pages_mapped := false;
    bufs_allocated := false;

    { the I/O map space; the command block's page at its start }
    iova := pbu_$alloc(iic_pbu_unit, false, 5, 0, status);
    if status.all <> status_$ok then
      return;
    pbu_allocated := true;
    wp_$calloc(cb_ppn, status);
    if status.all <> status_$ok then
      return;
    cb := addr(iic_$control_page[0][line]);
    mmu_$install(cb_ppn, cb, 0, 16#16);
    iic_map_iova(lshft(cb_ppn, 10), iova);
    pages_mapped := true;

    { the transmit pages }
    wp_$calloc(hdr_ppn, status);
    if status.all <> status_$ok then
      return;
    mmu_$install(hdr_ppn, addr(iic_$control_page[1][line]), 0, 16#16);
    tx_hdr_pa := lshft(hdr_ppn, 10);
    wp_$calloc(data_ppn, status);
    if status.all <> status_$ok then
      return;
    mmu_$install(data_ppn, addr(iic_$control_page[2][line]), 0, 16#16);
    tx_data_pa := lshft(data_ppn, 10);

    if not sock_$allocate(sock, 8, 10, 10, 1024) then begin
      status.all := status_$iic_no_receive_socket;
      return;
    end;
    ml_$exclusion_init(rcv_lock);
    ml_$exclusion_init(send_lock);
    sock_wait := ec_$read(sock_$socket_ptr[sock]^.ec) + 1;
    rx_hdr_iova := iova + 16#400;
    rx_data_iova := iova + 16#800;
    tx_hdr_iova := iova + 16#C00;
    tx_data_iova := iova + 16#1000;
    ec_$init(int_ec);
    counts.received := 0;
    counts.undocumented := 0;
    counts.remote_not_acquired := 0;
    counts.dma_timeouts := 0;
    for i := 1 to 6 do
      counts.events[i] := 0;

    { the receive buffers }
    netbuf_$get_hdr(rx_hdr_pa, rx_hdr_va);
    iic_map_iova(rx_hdr_pa, rx_hdr_iova);
    netbuf_$get_dat(rx_data_pa);
    iic_map_iova(rx_data_pa, rx_data_iova);
    bufs_allocated := true;

    { the reset }
    csr^.control := iic_csr_reset;
    time_$wait(time_$relative, iic_reset_hold, status);
    csr^.control := 0;
    tries := 1000;
    while (3 in csr^.status) and then (tries > 0) do begin
      time_$wait(time_$relative, iic_reset_poll, status);
      tries := tries - 1;
    end;
    if (tries = 0) and then (3 in csr^.status) then begin
      status.all := status_$iic_reset_timed_out;
      return;
    end;
    self_test_failed := 5 in csr^.status;

    { the command block's address, then the initialization }
    iova_bytes.all := iova;
    regs^.addr_hi := iova_bytes.b[2];
    regs^.addr_mid := iova_bytes.b[3];
    regs^.addr_lo := iova_bytes.b[4];
    csr^.control := iic_csr_ack;
    for i := 1 to 18 do
      cb^.longs[i] := 0;
    iic_command(line, iic_cmd_init, status);
    if status.all <> status_$ok then
      return;

    { the buffers' I/O addresses, then the receive setup }
    cb^.cb.xmit_hdr_iova := tx_hdr_iova;
    cb^.cb.xmit_data_iova := tx_data_iova;
    cb^.cb.rcv_hdr_iova := rx_hdr_iova;
    cb^.cb.rcv_data_iova := rx_data_iova;
    cb^.cb.hdr_max := 16;
    cb^.cb.data_max := 2048;
    iic_command(line, iic_cmd_receive, status);
    if status.all <> status_$ok then
      return;

    with cb^.cb do
      if not ((((revision[1] >= '2') and (revision[2] >= '1')) or
               ((revision[1] = '0') and (revision[2] = '0'))) and
              ((revision[3] = 'A') and (revision[4] = 'C'))) then begin
        status.all := status_$iic_wrong_board_revision;
        return;
      end;

    iic_send_link(line, iic_link_up, status);
    if self_test_failed and then (status.all = status_$ok) then
      status.all := status_$iic_self_test_failure;
  end;
end;
