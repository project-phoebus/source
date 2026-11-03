{ MT_$SIO - finish the controller's current request and start the next.

  Image addresses:
    sau3  0x00E70FD8  MT_$SIO
    sau5  0x00E76B48  MT_$SIO

  - With nil (MT_$INT, the controller's interrupt) it finishes the
    started block; an error that ends the chain marks every later block
    done too.  The result is 2 when the unit's queue is then empty.
  - With a unit record it starts that unit's first block, else the next
    pending unit's round the ring from MT_$SCB's cursor; the result has
    bit 0 set when a block starts.
  - The result is set only on the interrupt's path; a search that finds
    no unit starts the last head it loaded; a chained write's header
    copy uses the unit called for.

  Status stored: none.
}

function mt_$sio;
label
  9;
var
  dst: mt_$page_bytes_ptr_t;
  src: mt_$page_bytes_ptr_t;
  off: integer;
  result: integer;
  up: mt_$unit_ptr_t;
  pb: mt_$pb_ptr_t;
  cur: mt_$pb_ptr_t;
  ur: mt_$unit_ptr_t;
  u: integer;
  i: integer;
  k: integer;
  page: integer;
begin
  up := unit_rec;
  if up = nil then begin
    mt_$scb.flags.bits := mt_$scb.flags.bits + [12];
    result := 0;
    pb := mt_$scb.current;
    if pb = nil then begin
      mt_$scb.n_spurious := mt_$scb.n_spurious + 1;
      goto 9;
    end;
    u := pb^.mode_bits.drive;
    if pb^.mode_bits.high = 1 then
      u := 1;
    cur := pb;
    up := addr(mt_$scb.units[u]);
    if up^.queue.head = nil then begin
      mt_$scb.n_spurious := mt_$scb.n_spurious + 1;
      goto 9;
    end;
    up^.wait_count := up^.wait_count + 1;
    if (cur^.op = mt_op_read) and then (up^.hdr_addr <> 0) then begin
      dst := univ_ptr(up^.hdr_addr + cur^.hdr_offset);
      off := mt_$getiova(cur^.iova) & 16#3FF;
      src := univ_ptr(up^.hdr_addr + off);
      for i := 0 to 16#3FF - off do
        dst^[i] := src^[i];
    end;
    if 5 in mmu.status then begin
      cur^.tape_status := cur^.tape_status + [0];
      cur^.tape_status := cur^.tape_status - [14];
    end;
    if not (14 in cur^.tape_status)
       or else ((4 in cur^.tape_status)
                and (mt_unit_flag_9 in up^.flags.bits))
       or else ((7 in cur^.tape_status) and then (cur^.op = 16#1C)) then
      while pb <> nil do begin
        pb^.flags := pb^.flags + [mt_pb_done];
        pb := pb^.next;
      end
    else begin
      cur^.flags := cur^.flags + [mt_pb_done];
      pb := cur^.next;
    end;
    if pb = nil then begin
      up^.flags.bits := up^.flags.bits + [mt_unit_flag_11];
      up^.flags.bits := up^.flags.bits - [mt_unit_pending];
      result := 2;
      mt_$scb.cur_dcte := up^.dcte;
    end;
  end
  else
    pb := up^.queue.head;

  if pb = nil then
    for k := 1 to mt_$scb.n_units do begin
      ur := mt_$scb.cursor;
      mt_$scb.cursor := ur^.next;
      if not (mt_unit_flushing in ur^.flags.bits) then
        if mt_unit_pending in ur^.flags.bits then begin
          pb := ur^.queue.head;
          if pb <> nil then
            if not (mt_pb_done in pb^.flags) then
              exit;
        end;
    end;
  mt_$scb.current := pb;
  if pb = nil then begin
9:
    mt_$scb.flags.bits := mt_$scb.flags.bits - [mt_scb_busy];
  end
  else begin
    cur := pb;
    if mt_pb_built in cur^.flags then begin
      page := rshft(mt_$getiova(cur^.iova), 10);
%if long_iomap %then
      for k := 1 to cur^.npages do
        iomap[page + k - 1] := cur^.ppns[k] + mt_iomap_bias;
%else
      for k := 1 to cur^.npages do
        iomap[page + k - 1].entry := cur^.ppns[k] + mt_iomap_bias;
%endif
      if (cur^.op = mt_op_write) and then (up^.hdr_addr <> 0) then begin
        src := univ_ptr(up^.hdr_addr + cur^.hdr_offset);
        off := mt_$getiova(cur^.iova) & 16#3FF;
        dst := univ_ptr(up^.hdr_addr + off);
        for i := 0 to 16#3FF - off do
          dst^[i] := src^[i];
      end;
    end;
    mt_$putiova(mt_$get_iova(addr(cur^.op)), mt_$scb.cmd_iova);
    if 12 in mt_$scb.flags.bits then begin
      mt_$scb.ctl_word := 16#9FF;
      mt_$scb.flags.bits := mt_$scb.flags.bits - [12];
    end
    else
      mt_$scb.ctl_word := mt_ctl_word_reset;
    mt_$scb.flags.bits := mt_$scb.flags.bits + [mt_scb_busy];
    result := result ! 1;
    pbu_mt_page.reset := mt_ctl_reset;
  end;
  mt_$sio := result;
end;
