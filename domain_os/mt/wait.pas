{ MT_$WAIT - wait for a tape unit's started requests and report them.

  Image addresses:
    sau5  0x00E76952  MT_$WAIT

  - Waits on the unit's PBU eventcount for timeout seconds, an hour for
    0; a timeout clears the controller's busy member.
  - Whatever the wait's outcome, the queue's blocks are reported in info
    (up to max) and purged, and the unit leaves its pending state.

  Status stored:
    mt_$queue_request's status: the unit's check failed
    status_$mt_wait_before_go: not exactly one of the pending member and
      member 11 is set
    pbu_$wait's status: the requests ended
    status_$mt_wait_timeout: the wait timed out
    status_$mt_quit_in_wait: a quit ended the wait
    status_$mt_info_too_small: the queue has more than max blocks
}

procedure mt_$wait;
var
  ms: integer32;
  u: integer;
  t: integer32;
  i: integer;
  pb: mt_$pb_ptr_t;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  if status.all <> 0 then
    return;
  with mt_$scb.units[u] do begin
    if (mt_unit_pending in flags.bits) = (mt_unit_flag_11 in flags.bits)
    then begin
      status.all := status_$mt_wait_before_go;
      return;
    end;
    t := timeout;
    if t = 0 then
      t := mt_default_timeout
    else
      t := t * 1000;
    ms := t;
    case pbu_$wait(pbu_unit, ms, true, status) of
      pbu_$wait_timed_out: begin
        status.all := status_$mt_wait_timeout;
        mt_$scb.flags.bits := mt_$scb.flags.bits - [mt_scb_busy];
      end;
      pbu_$wait_quit: begin
        status.all := status_$mt_quit_in_wait;
      end;
    end;
    count := wait_count;
    pb := queue.head;
    i := 1;
    while pb <> nil do begin
      if i > max then begin
        status.all := status_$mt_info_too_small;
        exit;
      end;
      info[i].tape_status := pb^.tape_status;
      info[i].w_0c := pb^.word_0c;
      info[i].count := pb^.count;
      i := i + 1;
      pb := pb^.next;
    end;
    mt_purge_ucb(u);
    flags.bits := flags.bits - [mt_unit_pending, mt_unit_flag_11];
    wait_count := 0;
  end;
end;
