{ EXCS - execute a floppy controller command and judge its result.

  Image addresses:
    sau2  0x00E3E268  EXCS
    sau8  0x03C46486  EXCS

  - While command retries remain, an error spends one and becomes
    flp_$retry; a DMA overrun has its own budget.
  - A bad format on the wrong cylinder spends the retries on one
    recalibrate.
  - Global: a map symbol without `$'.

  Returns:
    SHAKE's or DMA_$CHECK's result: either fails
    a parity error: the transfer had one (not the AT bus form, which
      checks neither parity nor DMA here)
    the result registers' reading: otherwise (after SENSE DRIVE STATUS
      when ST0 shows an error)

  Status stored: none.
}

function excs(var cmd: univ flp_$words_t; in count: integer;
              in vol: disk_$volume_t): integer32;
var
  status: integer32;
  target: integer32;
  which: integer;
  unit: integer;
  st3: flp_$sreg_t;
%if not floppy_atbus %then
  parity_err: boolean;
%endif
begin
  { the command }
  target := flp_$ec.value + 1;
  status := shake(cmd, count, 1);
  if status <> status_$ok then begin
    excs := status;
    return;
  end;

  { the interrupt, or eight ticks }
  which := ec_$wait(addr(flp_$ec),
                    ec_$eventcount_ptr_t(addr(time_$clockh)),
                    addr(ec_$nil_ec), target, time_$clockh + 8, 0);

%if not floppy_atbus %then
  { parity and DMA, not after a RECALIBRATE }
  excs := status_$ok;
  if (cmd[0] & 7) <> 7 then begin
    if 1 in flp_hw_addr^.w_06 then begin
      parity_err := parity_$chk_io(1, flp_buf_pa) <> 0;
      if parity_err then begin
        excs := status_$memory_parity_error_during_disk_write;
        return;
      end;
    end;
    status := dma_$check(3);
    if (status <> status_$ok) and then
       (status <> status_$dma_not_at_end_of_range) then begin
      if flp_cmd_retry <> 0 then begin
        flp_cmd_retry := flp_cmd_retry - 1;
        excs := flp_$retry;
        return;
      end
      else begin
        excs := status;
        return;
      end;
    end;
  end;

%endif
  if which <> 0 then
    flp_$sregs[0].w := 16#10;
  if (flp_$sregs[0].w & 16#D8) = 0 then
    return;

  { the drive's status }
  flp_sense_cmd[1] := cmd[1];
  status := shake(flp_sense_cmd, 2, 1);
  if status = status_$ok then
    status := shake(st3, 1, 0);

  { the result registers }
  if status <> status_$ok then
    excs := status
  else if 4 in flp_$sregs[0].bits then
    excs := status_$disk_equipment_check
  else if 3 in flp_$sregs[0].bits then begin
    flp_cmd_retry := 0;
    if (not (3 in st3.bits)) and then (5 in st3.bits) and then
       (cmd[1] >= 4) then
      excs := status_$floppy_is_not_2_sided
    else
      excs := status_$disk_not_ready;
  end
  else if ((~flp_$sregs[0].w) & 16#C0) = 0 then begin
    excs := status_$disk_not_ready;
    flp_cmd_retry := 0;
  end
  else if 1 in flp_$sregs[1].bits then begin
    excs := status_$disk_write_protected;
    flp_cmd_retry := 0;
  end
  else if (flp_$sregs[1].w & 16#85) <> 0 then begin
    excs := status_$bad_disk_format;
    if (4 in flp_$sregs[2].bits) and then (flp_cmd_retry <> 0) then begin
      flp_cmd_retry := 1;
      unit := cmd[1] & 3;
      flp_recal_cmd[1] := unit;
      status := excs(flp_recal_cmd, 2, vol);
      flp_unit_cyl[unit] := 0;
      if status <> status_$ok then begin
        excs := status;
        flp_cmd_retry := 0;
      end;
    end;
  end
  else if 5 in flp_$sregs[1].bits then begin
    excs := status_$disk_data_check;
    if 1 in vol.as_options then
      return;
  end
  else if 4 in flp_$sregs[1].bits then begin
    if flp_dma_retry > 0 then begin
      flp_dma_retry := flp_dma_retry - 1;
      excs := flp_$retry;
      return;
    end
    else begin
      excs := status_$dma_overrun;
      return;
    end;
  end
  else
    excs := status_$unknown_status_returned_by_hardware;

  { a retry while the budget lasts }
  if flp_cmd_retry <> 0 then begin
    flp_cmd_retry := flp_cmd_retry - 1;
    excs := flp_$retry;
  end;
end;
