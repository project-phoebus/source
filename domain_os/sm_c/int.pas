{ SM_C_$INT - the SM_C controller's interrupt routine.

  Image addresses:
    sau3  0x00E6F0CA  SM_C_$INT
    sau5  0x00E74C2E  SM_C_$INT

  - The result is 3 when the chain ends (no request, its last, the
    register's bit 6 or a parity error): the controller is acknowledged
    and the PBU given the unit's eventcount to advance.
  - Otherwise 1: the chain's next request is set up and continued.
  - A DMA parity error marks the unit's parity flag.

  Status stored: none.
}

function sm_c_$int: integer;
var
  reg: pinteger;
  last: boolean;
  page: ^sm_c_$page_t;
begin
  page := addr(pbu_sm_c_page);
  with sm_$cb.c_unit[sm_c_unit] do begin
    reg := page^.cmd;
    if sm_c_req = nil then
      last := true
    else begin
      if parity_$during_dma then
        flags.parity_err :=
          parity_$chk_io(sm_c_cb_ppn, sm_c_req^.ppn) <> 0;
      if sm_$cb.c_cmd = sm_c_cmd_read then begin
        sm_c_req^.header.l := sm_c_hdr^;
        stats.xfers[1] := stats.xfers[1] + 1;
      end;
      last := sm_c_req^.next = nil;
    end;
    status.all := sm_$cb.c_status.all;
    flags.cmd_reg := reg;

    if last or ((reg & 16#40) <> 0) or flags.parity_err then begin
      page^.cmd := sm_c_reg_ack;
      sm_c_pbu_info^.int_ec := addr(ec);
      sm_c_$int := 3;
    end
    else begin
      sm_c_req := sm_c_req^.next;
      if sm_$cb.c_cmd = sm_c_cmd_write then begin
        sm_c_hdr^ := sm_c_req^.header.l;
        stats.xfers[2] := stats.xfers[2] + 1;
      end;
%if long_iomap %then
      sm_c_iomap_entry^ := sm_c_req^.ppn + sm_iomap_bias;
%else
      sm_c_iomap_entry^.entry := sm_c_req^.ppn + sm_iomap_bias;
%endif
      sm_$cb.c_b11 := 0;
      sm_$cb.c_status.all := 0;
      sm_$cb.c_daddr.cyl_lo := sm_c_req^.daddr.cyl & 16#FF;
      sm_$cb.c_daddr.cyl_hi := rshft(sm_c_req^.daddr.cyl, 8);
      sm_$cb.c_daddr.head := sm_c_req^.daddr.head;
      sm_$cb.c_daddr.sector := sm_c_req^.daddr.sector;
      sm_$cb.c_count := 1;
      sm_$cb.c_buf_lo := sm_c_hdr_lo.lo;
      sm_$cb.c_buf_mid := sm_c_hdr_mid.lo;
      page^.cmd := sm_c_reg_continue;
      sm_c_$int := 1;
    end;
  end;
end;
