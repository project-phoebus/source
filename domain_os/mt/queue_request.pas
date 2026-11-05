{ mt_$queue_request - check a tape unit and its owner, retire finished
  requests, and build and queue a request.

  Image addresses:
    sau3  0x00E6FC66  mt_$queue_request
    sau4  0x0F87C9DE  mt_$queue_request
    sau5  0x00E757CE  mt_$queue_request
    sau6  0x7807C496  mt_$queue_request

  - Unless op is mt_op_check_only, every unit's finished requests are
    first retired; mt_op_check and mt_op_check_only stop after the
    checks.  Unit 4 is taken as 1, and the caller's unit changed.
  - A read or write touches and records every page of its buffer and
    header; a page already wired is accepted, and then not unwired.
  - The queue is started (MT_$SIO) when the unit is pending and the
    controller is not busy.
  - A length of 16#8000 or more is taken as 0 or less.

  Status stored:
    status_$ok: the unit was checked, or the request queued
    status_$mt_invalid_unit_number: unit is not 0, 1 or 4
    status_$mt_not_acquired: the current process has not acquired it
    status_$mt_op_before_wait: a started request is outstanding
    status_$mt_go_not_in_batch_mode: mt_op_go, not in batch mode
    status_$mt_too_many_operations: no free request block
    status_$mt_invalid_buffer_length: a transfer's length is not
      1..mt_max_length, or its pages exceed the unit's I/O map region
    status_$mt_invalid_buffer_address: the buffer's end or the header
      is at or above AS_$PROTECTION
    pbu_$save_ppn's status, its fail bit set: a page could not be
      recorded (the block purged)
    pbu_$enable_device's status: the queue was started
}

procedure mt_$queue_request(var unit: integer; op: integer;
                            header: linteger; in buffer: univ mt_$buffer_t;
                            length: pinteger; out status: status_$t);
  internal;
label
  9;
var
  pb: mt_$pb_ptr_t;
  i: integer;
  save_unit: integer;
  start: linteger;
  va: linteger;
  last: linteger;
  npages: integer;
  k: integer;
  page: ^integer;
  dummy: integer;
begin
  if op <> mt_op_check_only then
    for i := 0 to mt_$scb.n_units - 1 do begin
      pb := mt_$scb.units[i].queue.head;
      while pb <> nil do begin
        if mt_pb_done in pb^.flags then
          mt_$purge_pb(i, pb, false);
        pb := pb^.next;
      end;
    end;
  status.all := 0;
  case unit of
    0, 1: { empty };
    4: begin
      unit := 1;
    end;
    otherwise begin
      status.all := status_$mt_invalid_unit_number;
      return;
    end;
  end;
  with mt_$scb.units[unit] do begin
    if not (mt_unit_acquired in flags.bits)
       or else (dcte^.owner <> proc1_$current) then begin
      status.all := status_$mt_not_acquired;
      return;
    end;
    case op of
      mt_op_check_only, mt_op_check: begin
        return;
      end;
      mt_op_go: begin
        if mt_unit_pending in flags.bits then begin
          status.all := status_$mt_op_before_wait;
          return;
        end
        else if not (mt_unit_batch in flags.bits) then begin
          status.all := status_$mt_go_not_in_batch_mode;
          return;
        end
        else
          flags.bits := flags.bits + [mt_unit_pending];
      end;
      otherwise begin
        if mt_unit_pending in flags.bits then begin
          status.all := status_$mt_op_before_wait;
          return;
        end;
        pb := mt_$deq(mt_$scb.free_q);
        if pb = nil then begin
          status.all := status_$mt_too_many_operations;
          return;
        end;
        if (op = mt_op_read) or else (op = mt_op_write) then begin
          if (length <= 0) or else (length > mt_max_length) then begin
            status.all := status_$mt_invalid_buffer_length;
            goto 9;
          end;
          start := integer32(addr(buffer));
          last := start + length - 1;
          va := start;
          pb^.buffer := start;
          pb^.header := 0;
          if last >= as_$protection then begin
            status.all := status_$mt_invalid_buffer_address;
            goto 9;
          end;
          npages := (last div 1024) - (start div 1024) + 1;
          page := addr(buffer);
          for k := 1 to npages do begin
            if op = mt_op_read then
              page^ := page^
            else
              dummy := page^;
            page := univ_ptr(integer32(page) + 1024);
          end;
          if header <> 0 then begin
            if header >= as_$protection then begin
              status.all := status_$mt_invalid_buffer_address;
              goto 9;
            end;
            va := header;
            pb^.header := header;
            npages := npages + 1;
            pb^.hdr_offset := hdr_offset;
          end;
          if npages > max_pages then begin
            status.all := status_$mt_invalid_buffer_length;
            goto 9;
          end;
          pb^.npages := npages;
          mt_$putiova((va & 16#3FF) ! iova_base, pb^.iova);
          pb^.length := length;
          save_unit := pbu_unit;
          pb^.flags := pb^.flags + [mt_pb_unwire, mt_pb_built];
          for k := 1 to npages do begin
            pb^.ppns[k] := pbu_$save_ppn(save_unit, va, status);
            if status.all = status_$pbu_page_already_wired then begin
              pb^.flags := pb^.flags - [mt_pb_unwire];
              status.all := 0;
            end;
            if status.all <> 0 then begin
              pb^.npages := k - 1;
              flags.bits := flags.bits + [mt_unit_purging];
              mt_$purge_pb(unit, pb, true);
              flags.bits := flags.bits - [mt_unit_purging];
              status.fail := true;
              return;
            end;
            if va = header then
              va := start
            else
              va := va + 16#400;
          end;
        end
        else
          pb^.count := length;
        pb^.op := op;
        pb^.mode_bits := mode_bits;
        pb^.word_0c := 0;
        pb^.tape_status := [];
        mt_$enq(queue, pb);
        flags.pending := not (mt_unit_batch in flags.bits);
      end;
    end;
    if mt_unit_pending in flags.bits then
      if not mt_$mt_busy then begin
        discard(mt_$sio(addr(mt_$scb.units[unit])));
        pbu_$enable_device(mt_pbu_unit, status);
      end;
  end;
  return;
9:
  mt_$enq(mt_$scb.free_q, pb);
end;
