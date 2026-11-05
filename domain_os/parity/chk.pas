{ PARITY_$CHK - diagnose and log a memory parity error.

  Image addresses:
    sau2  0x00E0AE68  PARITY_$CHK
    sau7  0x3C40C880  PARITY_$CHK
    sau8  0x03C0BE18  PARITY_$CHK
    sau9  0x3C40CD04  PARITY_$CHK

  - The error registers are read in the SAU1 layout (the error word) or
    the SAU2 one (the error longword), as MMU status member 0 says.
  - The failing frame is mapped at PAR_BUFF to find the failing word,
    and its own mapping restored after (removed, with no virtual
    address).  An error during DMA is only counted and logged.
  - Crashes the system when a check is under way, on an MMU parity
    error, when the spurious count wraps to 0, and when the page stays
    in and the frame's ASID is 0.
  - With `parity_err_regs' the lanes and the page come from MMU_BESR,
    MMU_PEARH and MMU_PEARL; an error that a CACHE_$CLEAR does not clear
    crashes the system.
  - A page of a DMA channel's transfer flags the channel and is only
    logged; else PAR_BUFF is read until MMU_BESR shows a lane.
  - With `parity_cpu_status' the lanes come from the CPU status
    register and the page from MMU_$PARITY_PPN; a page of a DMA
    channel's transfer, or status bit 10, is only logged (the page
    flagged); bit 0 of the privilege byte is off while PAR_BUFF's
    longwords are read until the register shows a lane.
  - With `parity_cache_check' as well, on a ROADRUNNER board the
    physical cache is off while the check runs, an error the cache
    register shows crashes the system first, and status bit 14 moves
    the error's address to the second longword of the memory's 8-byte
    word; an error with status bit 9 (an AT bus channel check) is only
    logged, and one that is still set when no lane failed crashes the
    system.
  - Returns false for a DMA or spurious error, else true.

  Status stored: none.
}

%if parity_err_regs %then

{ TODO(pascal) 20 frame bytes unexplained (stand-ins unused_1c .. unused_22, unused_3c)

  The SAU9 image's frame is 0x3C bytes and addresses only log_entry,
  saved_asid, did_install, result and the `with' temporary of
  PARITY_$INFO's address (below result).  The register-held locals take
  the slots above saved_asid; the 8 bytes between saved_asid and
  did_install and 12 bytes below the `with' temporary are the
  stand-ins.  The SAU2 frame has 16 such bytes (below); the SAU7's
  PARITY_$CHK, the other form with this code's shape, has other locals
  at other offsets.  What the original declared is not known. }

function parity_$chk: boolean;
label
  spurious, handle_error, log_error, finish;
var
  data: integer;
  word_index: integer;
  lane: integer;
  log_entry: parity_$log_entry_t;
  i: integer;
  ch: integer;
  j: integer;
  found: boolean;
  saved_asid: integer;
  unused_1c: integer;                     { the stand-ins (TODO) }
  unused_1e: integer;
  unused_20: integer;
  unused_22: integer;
  did_install: boolean;
  result: boolean;
  unused_3c: array[1..6] of integer;      { the stand-in (TODO) }
begin
  result := true;
  did_install := false;
  with parity_$info do begin
    err.pa := 0;
    err.va := 0;
    err_data := 0;

    { a check under way }
    if chk_in_progress then
      crash_system(fault_$parity);
    chk_in_progress := true;

    { the latched error: no lane failed, a spurious one }
    err_status.all := mmu_besr.all;
    if (err_status.lane_0_ok = 1) and (err_status.lane_1_ok = 1)
       and (err_status.lane_2_ok = 1) and (err_status.lane_3_ok = 1) then
      goto spurious;
    err_ppn := lshft(ord(mmu_pearh), 8) + ord(mmu_pearl) + 16#10000;
    err.pa := lshft(err_ppn, 10);

    { the error must clear }
    mmu_ccr.bit_4 := true;
    cache_$clear;
    mmu_ccr.bit_4 := false;
    if (mmu_besr.lane_3_ok = 0) or else (mmu_besr.lane_2_ok = 0)
       or else (mmu_besr.lane_0_ok = 0) or else (mmu_besr.lane_1_ok = 0) then
      crash_system(fault_$parity);

    { a page of a DMA channel's transfer: the channel flagged, the
      error only logged }
    found := false;
    for ch := 0 to parity_dma_channels - 1 do begin
      with parity_$dma_table[ch] do
        if npages <> 0 then
          for j := 1 to npages do
            if pages[j] = err_ppn then begin
              took_error := true;
              found := true;
              exit;
            end;
      if found then
        exit;
    end;
    if found then begin
      result := false;
      goto log_error;
    end;

    { the page's address and ASID }
    if not ast_$ptov(err_ppn, saved_asid, err.va) then
      crash_system(fault_$parity);

    { the frame at the scratch page }
    mmu_ccr.bit_2 := true;
    mmu_$install(err_ppn, addr(par_buff), 0, parity_scratch_prot);
    did_install := true;

    { read the page until the register shows a lane }
    lane := -1;
    for i := 0 to 255 do begin
      data := par_buff[i];
      if mmu_besr.lane_0_ok = 0 then
        lane := 0
      else if mmu_besr.lane_1_ok = 0 then
        lane := 1
      else if mmu_besr.lane_2_ok = 0 then
        lane := 2
      else if mmu_besr.lane_3_ok = 0 then
        lane := 3;
      if lane >= 0 then begin
        word_index := i;
        err.pa := word_index * 4 + lane + lshft(err_ppn, 10);
        err.va := err.va + (lane + word_index * 4);
        if lane < 2 then
          err_data := rshft(data, 16)
        else
          err_data := data;

        { the error must clear }
        mmu_ccr.bit_4 := true;
        cache_$clear;
        mmu_ccr.bit_4 := false;
        if (mmu_besr.lane_3_ok = 0) or else (mmu_besr.lane_2_ok = 0)
           or else (mmu_besr.lane_0_ok = 0)
           or else (mmu_besr.lane_1_ok = 0) then
          crash_system(fault_$parity);
        goto handle_error;
      end;
    end;

    { no error found }
spurious:
    spurious_count := spurious_count + 1;
    result := false;
    if spurious_count = 0 then
      crash_system(fault_$spurious_parity);
    goto finish;

    { take the page out, or write the word back }
handle_error:
    if ast_$remove_corrupted_page(err_ppn) then
      did_install := false
    else begin
      if saved_asid = 0 then
        crash_system(fault_$parity);
      par_buff[word_index] := data;
    end;

log_error:
    mem_$parity_log(mem_$phys_addr_t(err.pa));

    { the system log }
finish:
    log_entry.status := err_status;
    log_entry.addrs := err;
    log_$add(3, log_entry, 10);

    { the scratch page's mapping out }
    mmu_ccr.bit_2 := false;
    if did_install then
      mmu_$remove(addr(par_buff), 0);
    cache_$clear;
  end;
  parity_$chk := result;
end;
%elseif parity_cpu_status %then

{ TODO(pascal) 12 frame bytes unexplained (stand-ins unused_a .. unused_c)

  The SAU8 image's frame is 0x3C bytes and addresses log_entry right
  below the reserved slot, saved_asid 12 bytes below it, did_install
  and result below that, and a byte the first `or' chain keeps (below
  result).  The 12 bytes between log_entry and saved_asid are the
  stand-ins; they are the size of the register-held data, word_index,
  lane, i and ch, but whether the original's register locals had frame
  slots there is not known (three longwords here: a 12-byte object
  would be placed at a multiple of 8).  dpc keeps did_install and result in
  registers. }

function parity_$chk: boolean;
label
  spurious, handle_error, log_error, finish;
var
  log_entry: parity_$log_entry_t;
  unused_a: integer32;                    { the stand-ins (TODO) }
  unused_b: integer32;
%if parity_cache_check %then
  cache_status: parity_$cache_status_t;
%endif
  unused_c: integer32;
  saved_asid: integer;
  did_install: boolean;
  result: boolean;
  data: integer32;
  word_index: integer;
  lane: integer;
  i: integer;
  ch: integer;
  found: boolean;
begin
%if parity_cache_check %then
  { the physical cache off; an error of its own crashes the system }
  if roadrunner then begin
    cache_$disable_physical;
    cache_status := mmu.cache;
    if cache_status.bit_15 or else cache_status.bit_14
       or else cache_status.bit_9 or else cache_status.bit_13 then
      crash_system(fault_$cache_parity);
  end;
%endif
  result := true;
  did_install := false;
  with parity_$info do begin
    err.va := 0;
    err.pa := 0;
    err_data := 0;
%if parity_cache_check %then
    err_longword := 0;
%endif

    { a check under way }
    if chk_in_progress then
      crash_system(fault_$parity);
    chk_in_progress := true;

    { the latched error: no lane failed, a spurious one }
    err_status := mmu.status;
    if not (err_status.lane_0_err or err_status.lane_1_err
            or err_status.lane_2_err or err_status.lane_3_err) then
      goto spurious;
%if parity_cache_check %then
    err_ppn := mmu_$parity_ppn;
    if roadrunner and then err_status.bit_14 then
      err_longword := 1;
    err.pa := lshft(err_ppn, 10);
    mmu.status.all := 0;
    if roadrunner then
      err.pa := err.pa + err_longword * 4;
%else
    err_ppn := mmu_$parity_ppn & 16#3FFF;
    err.pa := lshft(err_ppn, 10);
    mmu.status.all := 0;
%endif

    { a page of a DMA channel's transfer, or bit 10: the page flagged,
      the error only logged }
    found := false;
    for ch := 0 to parity_dma_channels - 1 do
      with parity_$dma_table[ch] do
        if err_ppn = ppn[1] then begin
          took_error[1] := true;
          found := true;
          exit;
        end
        else if err_ppn = ppn[2] then begin
          took_error[2] := true;
          found := true;
          exit;
        end;
%if parity_cache_check %then
    if (found or err_status.bit_10) or else err_status.bit_9 then begin
%else
    if found or else err_status.bit_10 then begin
%endif
      result := false;
      goto log_error;
    end;

    { the page's address and ASID }
    if not ast_$ptov(err_ppn, saved_asid, err.va) then
      crash_system(fault_$parity);

    { the frame at the scratch page, bit 0 of the privilege byte off }
    mmu_$pid_priv.bit_0 := false;
    mmu.control.priv := mmu_$pid_priv.priv;
    mmu_$install(err_ppn, addr(par_buff), 0, parity_scratch_prot);
    did_install := true;

    { read the page until the register shows a lane }
    lane := -1;
    for i := 0 to 255 do begin
      data := par_buff[i];
      if mmu.status.lane_0_err then
        lane := 0
      else if mmu.status.lane_1_err then
        lane := 1
      else if mmu.status.lane_2_err then
        lane := 2
      else if mmu.status.lane_3_err then
        lane := 3;
      if lane >= 0 then begin
        word_index := i;
        err.pa := word_index * 4 + lane + lshft(err_ppn, 10);
        err.va := err.va + (lane + word_index * 4);
        if lane < 2 then
          err_data := rshft(data, 16)
        else
          err_data := data;
        mmu.status.all := 0;
        goto handle_error;
      end;
    end;

    { no error found }
spurious:
%if parity_cache_check %then
    if mmu.status.bit_9 then
      crash_system(fault_$io_chan_chk);
    mmu.status.all := 0;
%endif
    spurious_count := spurious_count + 1;
    result := false;
    if spurious_count = 0 then
      crash_system(fault_$spurious_parity);
    goto finish;

    { take the page out, or write the longword back }
handle_error:
    if ast_$remove_corrupted_page(err_ppn) then
      did_install := false
    else begin
      if saved_asid = 0 then
        crash_system(fault_$parity);
      par_buff[word_index] := data;
    end;

log_error:
    mem_$parity_log(mem_$phys_addr_t(err.pa));

    { the system log }
finish:
    log_entry.status := err_status;
    log_entry.addrs := err;
    log_$add(3, log_entry, 10);

    { bit 0 of the privilege byte on, the scratch page's mapping out }
    mmu_$pid_priv.bit_0 := true;
    mmu.control.priv := mmu_$pid_priv.priv;
    if did_install then
      mmu_$remove(addr(par_buff), 0);
    cache_$clear;
  end;
%if parity_cache_check %then
  if roadrunner then
    cache_$enable_physical;
%endif
  parity_$chk := result;
end;
%else

{ TODO(pascal) 16 frame bytes unexplained (stand-ins unused_38, unused_3a)

  Below result the SAU2 image addresses nothing in the frame: two bytes
  are the function's result variable, never written, and the stand-ins
  hold the other 16 (one 16-byte object would be placed where these
  bytes do not start).  Candidates: pointer locals for the PFT entry and
  the scan, a scan count, a copy of the error longword; what the
  original declared is not known. }

function parity_$chk: boolean;
label
  spurious, handle_error, log_error, finish;
var
  log_entry: parity_$log_entry_t;
  err_long: mmu_$mem_err_t;
  word_index: integer;
  err_data: pinteger;
  byte_offset: integer;
  saved_prot: integer;
  saved_asid: integer;
  is_sau1: boolean;
  no_error: boolean;
  lanes: integer;
  i: integer;
  did_install: boolean;
  result: boolean;
  unused_38: array[1..7] of integer;      { the stand-in (TODO) }
  unused_3a: integer;
begin
  result := true;
  did_install := false;
  parity_$info.err.pa := 0;
  parity_$info.err.va := 0;
  parity_$info.err_data := 0;

  { a check under way, or an MMU parity error }
  if parity_$info.chk_in_progress or else (1 in mmu.status) then
    crash_system(fault_$parity);
  parity_$info.chk_in_progress := true;

  { the latched error }
  is_sau1 := 0 in mmu.status;
  if is_sau1 then begin
    parity_$info.err_status := mmu.mem_err.word;
    no_error := not (parity_$info.err_status.sau1_byte_lower
                     or parity_$info.err_status.sau1_byte_upper);
    if no_error then
      goto spurious;
    parity_$info.err_ppn := mmu.mem_err.word.sau1_ppn;
    parity_$info.err.pa := lshft(parity_$info.err_ppn, 10);
    mmu.mem_err.word.all := 0;
    parity_$during_dma := parity_$info.err_status.sau1_dma;
  end
  else begin
    err_long := mmu.mem_err;
    parity_$info.err_status := err_long.word;
    no_error := err_long.word.sau2_lanes = 15;
    if no_error then
      goto spurious;
    parity_$info.err.pa := lshft(rshft(err_long.all, 12), 2);
    parity_$info.err_ppn := rshft(parity_$info.err.pa, 10);
    mmu.mem_err.word.all := 0;
    parity_$during_dma := err_long.word.sau2_dma_upper
                          or err_long.word.sau2_dma_lower;
  end;

  { an error during DMA is only logged }
  if parity_$during_dma then begin
    result := false;
    goto log_error;
  end;

  { the page's address, the frame's ASID and
    protection }
  parity_$info.err.va := mmu_$ptov(parity_$info.err_ppn);
  saved_asid := pft[parity_$info.err_ppn].asid;
  saved_prot := pft[parity_$info.err_ppn].prot;

  { the frame at the scratch page }
  mmu_$install(parity_$info.err_ppn, addr(par_buff), 0, parity_scratch_prot);
  did_install := true;
  byte_offset := 0;

  if is_sau1 then begin
    { SAU1, read the page until the register
      shows the failing word }
    for i := 0 to 511 do begin
      err_data := par_buff[i];
      if mmu.mem_err.word.sau1_byte_lower
         or else mmu.mem_err.word.sau1_byte_upper then begin
        word_index := i;
        if mmu.mem_err.word.sau1_byte_upper then
          byte_offset := 1;
        parity_$info.err.pa := parity_$info.err.pa
                               + (byte_offset + word_index * 2);
        parity_$info.err.va := parity_$info.err.va
                               + (byte_offset + word_index * 2);
        parity_$info.err_data := err_data;
        mmu.mem_err.word.all := 0;
        goto handle_error;
      end;
    end;
  end
  else begin
    { SAU2, the word from the address }
    if (err_long.word.sau2_lanes & 3) <> 3 then
      word_index := 0
    else
      word_index := 1;
    word_index := word_index + rshft(parity_$info.err.pa & 16#3FF, 1);
    err_data := par_buff[word_index];
    lanes := mmu.mem_err.word.sau2_lanes;
    if lanes = 15 then
      goto spurious;
    if (lanes & 16#A) <> 16#A then
      byte_offset := 1;
    parity_$info.err.pa := parity_$info.err.pa + byte_offset;
    parity_$info.err.va := parity_$info.err.va
                           + (byte_offset + word_index * 2);
    parity_$info.err_data := err_data;
    mmu.mem_err.word.all := 0;
    goto handle_error;
  end;

  { no error found }
spurious:
  parity_$info.spurious_count := parity_$info.spurious_count + 1;
  result := false;
  if parity_$info.spurious_count = 0 then
    crash_system(fault_$spurious_parity);
  goto finish;

  { take the page out, or write the word back }
handle_error:
  if ast_$remove_corrupted_page(parity_$info.err_ppn) then
    did_install := false
  else begin
    if saved_asid = 0 then
      crash_system(fault_$parity);
    par_buff[word_index] := err_data;
  end;

log_error:
  mem_$parity_log(mem_$phys_addr_t(parity_$info.err.pa));

  { the system log }
finish:
  log_entry.status := parity_$info.err_status;
  log_entry.addrs := parity_$info.err;
  log_$add(3, log_entry, 10);

  { parity checking on again }
  if is_sau1 then
    mmu.mem_err.sau1_enable := chr(1)
  else
    mmu.mem_err.word.all := mmu.mem_err.word.all ! 16#40;

  { the frame's own mapping back }
  if did_install then
    if parity_$info.err.va <> 0 then
      mmu_$install(parity_$info.err_ppn, univ_ptr(parity_$info.err.va),
                   saved_asid, saved_prot)
    else
      mmu_$remove(parity_$info.err_ppn);

  cache_$clear;
  parity_$chk := result;
end;
%endif
