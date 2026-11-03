{ FLP_DO_IO - do one floppy request.

  Image addresses:
    sau2  0x00E3DDC6  FLP_DO_IO
    sau8  0x03C45D74  FLP_DO_IO

  - The controller's ML lock (its DCTE's disk_error_que_hi) is held
    throughout.
  - A write to a drive whose disk has changed, or a disk change during
    the transfer, fails with status_$storage_module_stopped.
  - A failure's status goes into the request, and the requesting
    process's pending flag is cleared.
  - The AT bus form takes the lock only when not locked (a format
    request unlocks in any case), and moves each sector on DMA channel
    2 with the motor on.
  - It reads each written sector back into the overrun page (FLP_DO_IO
    itself, locked); a failed read-back, or a last longword unlike the
    written page's (at FLP_PAGE), writes the sector again.
  - A bad format switches the motor off.
  - Global: a map symbol without `$'.

  Status stored: none.
}

%if floppy_atbus %then
procedure flp_do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; locked: boolean;
                    out result: boolean);
  options(val_param);
label
  10, 20;
var
  status: integer32;
  done: integer;
  unit: integer;
  dir: integer;
  pa: integer32;
  st: status_$t;
  residue: integer32;
  last: integer32;
  old_sr: integer;
begin
  flp_hw_addr := flp_ctlr_table[vol.dev_info^.controller].hw_addr;
  result := false;
  flp_l_168 := 0;
  flp_$overrun_rec.count := flp_$overrun_rec.count + 1;
  mmu_$install(req.ppn, addr(flp_page), 0, 16#16);
  if not locked then
    ml_$lock(flp_ctlr_table[vol.dev_info^.controller].dcte^.lock);
  if flp_hw_addr^.dig_in > 127 then
    flp_disk_change[vol.dev_unit] := true;
  flp_$turn_motor_on;

  if req.owner_op.op = disk_$req_op_format_track then begin
    flp_format_track(vol, req);
    ml_$unlock(flp_ctlr_table[vol.dev_info^.controller].dcte^.lock);
  end
  else begin
    { a write to a changed disk }
    if (req.owner_op.op = disk_$req_op_write) and then
       flp_disk_change[vol.dev_unit] then
      goto 10;

    flp_cmd_retry := 25;
    flp_dma_retry := 16#7FFF;
    flp_buf_pa := req.ppn;
    done := 0;

    repeat
      if (flp_hw_addr^.main_status & 16#1F) <> 0 then begin
        status := status_$disk_controller_busy;
        flp_hw_addr^.main_status := 0;
        goto 20;
      end;

      { the sector on channel 2 }
      if req.owner_op.op = disk_$req_op_read then
        dir := 0
      else
        dir := 1;
      pa := lshft(req.ppn, 10);
      dma_$start_ncheck(2, 1024, pa, dir, 0, st);
      if st.all <> status_$ok then begin
        status := st.all;
        goto 20;
      end;
      if flp_hw_addr^.dig_in > 127 then
        flp_disk_change[vol.dev_unit] := true;

      { the READ/WRITE DATA block }
      flp_rw_cmd[1] := req.daddr.head * 4 + vol.dev_unit;
      flp_rw_cmd[2] := req.daddr.cyl;
      flp_rw_cmd[3] := req.daddr.head;
      flp_rw_cmd[4] := req.daddr.sector + done + 1;

      { seek with the block's first words }
      unit := vol.dev_unit;
      status := status_$ok;
      if flp_unit_cyl[unit] <> req.daddr.cyl then begin
        flp_rw_cmd[0] := 16#0F;
        status := excs(flp_rw_cmd, 3, vol);
        flp_unit_cyl[unit] := flp_$sregs[1].w;
      end;

      { the transfer }
      if status = status_$ok then begin
        if req.owner_op.op = disk_$req_op_read then
          flp_rw_cmd[0] := flp_base_cmd + 6
        else
          flp_rw_cmd[0] := flp_base_cmd + 5;
        status := excs(flp_rw_cmd, 9, vol);
      end;
      dma_$stop(2, residue, st);

      if status = status_$ok then begin
        if st.all <> status_$ok then
          status := st.all;
        if status = status_$ok then begin
          { a write read back into the overrun page }
          if req.owner_op.op = disk_$req_op_write then begin
            flp_$overrun_rec.req := req;
            flp_$overrun_rec.req.owner_op.op := disk_$req_op_read;
            flp_$overrun_rec.req.ppn := flp_ovrrun_ppn;
            flp_rb_req := addr(flp_$overrun_rec.req);
            flp_page_last :=
              flp_$long_ptr_t(integer32(addr(flp_page)) + 16#3FC);
            last := flp_page_last^;
            flp_do_io(vol, flp_rb_req^, flp_rb_param^, true, result);
            if flp_$overrun_rec.req.status.all <> status_$ok then
              status := flp_$retry
            else if flp_ovrrun_last^ <> last then begin
              status := flp_$retry;
              flp_$ovrrun_ctr := flp_$ovrrun_ctr + 1;
            end
            else
              status := status_$ok;
          end;
          if status = status_$ok then
            done := done + 1;
        end;
      end;

      if (done = 0) and then (status = status_$ok) then
        status := flp_$retry;
    until status <> flp_$retry;

    { a disk change during the transfer }
    if (status = status_$ok) and then flp_disk_change[vol.dev_unit] then
10:   status := status_$storage_module_stopped;

20: if status <> status_$ok then begin
      disk_bptbl[req.owner_op.owner].io_pending := false;
      req.status.all := status;
      if status = status_$bad_disk_format then begin
        old_sr := set_sr(16#2700);
        flp_$motor_on := false;
        flp_$used := false;
        flp_$shut_down_motor;
        discard(set_sr(old_sr));
      end;
    end;

    if not locked then
      ml_$unlock(flp_ctlr_table[vol.dev_info^.controller].dcte^.lock);
  end;
end;
%else

procedure flp_do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                    in param_3: univ integer32; zero: integer;
                    out result: boolean);
  options(val_param);
label
  10;
var
  status: integer32;
  done: integer;
  unit: integer;
  unused_c: integer32;                    { stand-in }
  unused_10: integer32;                   { stand-in }
begin
  with flp_ctlr_table[vol.dev_info^.controller] do begin
    flp_hw_addr := hw_addr;
    result := false;
    ml_$lock(dcte^.disk_error_que_hi);

    if req.owner_op.op = disk_$req_op_format_track then
      flp_format_track(vol, req)
    else begin
      { a write to a changed disk }
      if (req.owner_op.op = disk_$req_op_write) and then
         flp_disk_change[vol.dev_unit] then
        status := status_$storage_module_stopped
      else begin

        flp_cmd_retry := 25;
        flp_dma_retry := 500;
        flp_buf_pa := req.ppn;
        done := 0;

        repeat
          if (flp_hw_addr^.main_status & 16#1F) <> 0 then begin
            status := status_$disk_controller_busy;
            goto 10;
          end;

          { the READ/WRITE DATA block }
          flp_rw_cmd[1] := req.daddr.head * 4 + vol.dev_unit;
          flp_rw_cmd[2] := req.daddr.cyl;
          flp_rw_cmd[3] := req.daddr.head;
          flp_rw_cmd[4] := req.daddr.sector + done + 1;

          { seek with the block's first words }
          unit := vol.dev_unit;
          status := status_$ok;
          if flp_unit_cyl[unit] <> req.daddr.cyl then begin
            flp_rw_cmd[0] := 16#0F;
            status := excs(flp_rw_cmd, 3, vol);
            flp_unit_cyl[unit] := flp_$sregs[1].w;
          end;

          { the transfer }
          if status = status_$ok then begin
            if req.owner_op.op = disk_$req_op_read then
              flp_hw_addr^.control := 2
            else
              flp_hw_addr^.control := 3;
            dma[3].mtc := 16#200;
            dma[3].mar := lshft(req.ppn, 10);
            if req.owner_op.op = disk_$req_op_write then
              dma[3].ocr := chr(16#12)
            else
              dma[3].ocr := chr(16#92);
            dma[3].mfc := chr(1);
            dma[3].ccr := chr(16#80);
            if req.owner_op.op = disk_$req_op_read then
              flp_rw_cmd[0] := flp_base_cmd + 6
            else
              flp_rw_cmd[0] := flp_base_cmd + 5;
            status := excs(flp_rw_cmd, 9, vol);
            if status = status_$ok then
              done := done + 1;
          end;

          if (done = 0) and then (status = status_$ok) then
            status := flp_$retry;
        until status <> flp_$retry;

        { a disk change during the transfer }
        if (status = status_$ok) and then flp_disk_change[vol.dev_unit]
        then
          status := status_$storage_module_stopped;

        flp_hw_addr^.control := 3;
      end;

  10: if status <> status_$ok then begin
        disk_bptbl[req.owner_op.owner].io_pending := false;
        req.status.all := status;
      end;
    end;

    ml_$unlock(dcte^.disk_error_que_hi);
  end;
end;
%endif
