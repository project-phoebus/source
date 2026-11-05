{ ct_scsi_transfer - read or write blocks between the tape and a list of
  buffers.

  Image addresses:
    sau7  0x3C484E36  build_entry (nested)
    sau7  0x3C484F8E  do_xfer (nested)
    sau7  0x3C48500C  ct_scsi_transfer (module-local)
    sau9  0x3C47757C  build_entry (nested)
    sau9  0x3C4776D2  do_xfer (nested)
    sau9  0x3C477750  ct_scsi_transfer (module-local)

  - The buffers (512-byte blocks) are touched, then taken in rounds of
    up to 9 runs of adjacent buffers, each within the largest transfer.
  - A round's runs are wired, then moved one command each (90 seconds'
    wait), a run unwired once the next one is under way.
  - A failed command's count done is cut by the sense's residue when it
    has one, or counted as none.
  - The runs still wired are unwired at the end, and the count done
    returned; a failure ends the transfer state.

  Status stored:
    status_$ok: the blocks were transferred
    status_$ct_invalid_operation_count: a count outside 1..512
    ct_touch_pages's result: a buffer at or above OS_LOW
    status_$ct_invalid_buffer_address: the same, found building a run
    status_$ct_bad_buffer_alignment: a buffer not 512-byte aligned
    SCSI_$WIRE's, SCSI_$DO_COMMAND's or SCSI_WAIT's status: those failed
    SCSI_$UNWIRE's status: the transfer passed but an unwire failed
}

procedure ct_scsi_transfer(unit: integer; in pages: univ ct_$page_list_t;
                           npages: integer; dir: integer;
                           out ndone: integer; out status: status_$t);
  internal;
label
  10, 20;
type
  byte_ptr_t = ^char;

  { A run of adjacent buffers: its first buffer, its length, whether
    it is wired. }
  entry_t = record
    buf: byte_ptr_t;                      { 0x00 }
    len: integer32;                       { 0x04 }
    wired: boolean;                       { 0x08 }
    unused_0a: integer;                   { 0x0A: stand-in }
  end;
var
  entries: array[1..9] of entry_t;
  residue: integer32;
  st2: status_$t;
  st1: status_$t;
  k: pinteger;
  j: pinteger;
  n: integer;
  touch: boolean;
  wired: integer;
  done: integer;
  more: boolean;
  blocks: integer32;

  { build_entry - build run j from buffer k on: true if it has a buffer.
    k is left at the buffer after the run. }
  function build_entry(out st: status_$t): boolean;
  var
    ok: boolean;
    first: integer32;
    p: integer32;
  begin
    st.all := 0;
    build_entry := false;
    entries[j].wired := false;
    if k > n then
      return;
    ok := true;
    entries[j].buf := byte_ptr_t(pages[k]);
    first := pages[k];
    entries[j].len := 512;
    while ok do begin
      p := pages[k];
      if linteger(p) >= linteger(addr(os_low)) then
        st.all := status_$ct_invalid_buffer_address
      else if (p & 16#1FF) <> 0 then
        st.all := status_$ct_bad_buffer_alignment;
      if st.all <> 0 then begin
        ok := false;
        exit;
      end;
      { The next buffer joins the run if it follows this one and the run
        stays within ct_max_kb kilobytes. }
      if (k <> n) and then (pages[k] + 512 = pages[k + 1])
         and then ((first + entries[j].len + 511) div 1024
                   - first div 1024 + 1 <= ct_max_kb) then
        entries[j].len := entries[j].len + 512
      else
        ok := false;
      k := k + 1;
    end;
    if st.all = 0 then
      build_entry := true;
  end;

  { do_xfer - start the read or write of one run. }
  function do_xfer(buf: byte_ptr_t; len: integer32): integer32;
  var
    st: status_$t;
    xdir: integer;
  begin
    ct_init_cdb;
    ct_cmd_cdb.t.rest := ct_scsi_fixed;
    ct_cmd_cdb.t.len := ct_to_24(rshft(len, 9));
    if dir = scsi_$dir_in then begin
      ct_cmd_cdb.t.op := ct_scsi_op_read;
      xdir := scsi_$dir_in;
    end
    else begin
      ct_cmd_cdb.t.op := ct_scsi_op_write;
      xdir := scsi_$dir_out;
    end;
    scsi_$do_command(ct_handle, ct_cmd_cdb, buf^, len, xdir, ct_req_id, st);
    do_xfer := st.all;
  end;

begin
  if (npages <= 0) or else (npages > 512) then begin
    status.all := status_$ct_invalid_operation_count;
    return;
  end;
  n := npages;
  if dir = scsi_$dir_in then begin
    ct_io_state := ct_state_read;
    touch := true;
  end
  else begin
    ct_io_state := ct_state_write;
    touch := false;
  end;
  wired := 0;
  k := 1;
  st1.all := 0;
  st2.all := 0;
  done := 0;
  status.all := ct_touch_pages(pages, n, touch);
  if status.all <> 0 then
    goto 20;

  while k <= n do begin
    { wire up to 9 runs }
    j := 1;
    wired := 0;
    more := true;
    while more do begin
      more := build_entry(status);
      if status.all <> 0 then
        goto 20;
      if more then begin
        scsi_$wire(ct_handle, entries[j].buf^, entries[j].len, status);
        if status.all <> 0 then
          goto 20;
        entries[j].wired := true;
        wired := wired + 1;
      end;
      j := j + 1;
      if j > 9 then
        more := false;
    end;

    { one command per run }
    if wired <> 0 then
      for j := 1 to wired do begin
        blocks := rshft(entries[j].len, 9);
        status.all := do_xfer(entries[j].buf, entries[j].len);
        if status.all <> 0 then
          goto 20;
        ct_busy := true;
        if j > 1 then
          if entries[j - 1].wired then begin
            scsi_$unwire(ct_handle, entries[j - 1].buf^, entries[j - 1].len,
                         touch, st1);
            entries[j - 1].wired := false;
          end;
        status.all := scsi_wait(ct_scsi_xfer_timeout, true);
        if status.all <> 0 then
          if ct_sense.f.valid then begin
            residue := ct_sense.info;
            blocks := blocks - residue;
          end
          else
            blocks := 0;
        done := done + blocks;
        if status.all <> 0 then
          goto 10;
      end;
    scsi_$unwire(ct_handle, entries[wired].buf^, entries[wired].len, touch,
                 st2);
    entries[wired].wired := false;
  end;

10:
  if status.all = 0 then begin
    status := st1;
    if status.all = 0 then
      status := st2;
  end;

20:
  if wired <> 0 then
    for j := 1 to wired do
      if entries[j].wired then begin
        scsi_$unwire(ct_handle, entries[j].buf^, entries[j].len, touch, st1);
        if status.all = 0 then
          status := st1;
      end;
  ndone := done;
  if status.all <> 0 then
    ct_io_state := ct_state_none;
end;
