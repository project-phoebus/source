{ EC2_$WAIT - wait until one of a list of level-2 eventcounts reaches
  its value.

  Image addresses:
    sau2  0x00E42358  EC2_$WAIT

  - Under a cleanup handler and the EC2 lock, each round threads a
    waiter record onto the ring of each eventcount given by its address.
  - Each given by an EC2 number goes into the EC_$WAITN list, after the
    process's wait eventcount and the quit eventcount.
  - The wait is done with the lock released.  The entries are then
    undone, last first; the lowest one reached is the result, else the
    round is repeated.
  - The fault path frees the waiter records recorded so far.

  Status stored:
    status_$ok: an entry was reached
    ec2_$no_wait_entries: necs is above 128, or no record or EC_$WAITN
      slot is left
    ec2_$bad_eventcount: an EC2 number or a ring is bad
    fault_$prot_violation: an address is at or above AS_$PROTECTION
    ec2_$wait_quit: a quit ended the wait
}

{ TODO(pascal) EC2_$WAIT's frame against its locals

  The frame is 0x290 bytes.  Placed as the declarations give them, the
  image then has 26 bytes no instruction addresses, satisfied, the
  result variable, necs's copy, the `for' count (a compiler temporary),
  28 more open bytes, and eight stepped-pointer temporaries.  The 26
  bytes are too few for the register-held locals declared here (each
  keeps a slot); dpc allocates none of the temporaries.  Not settled. }

function ec2_$wait(in ec_plist: univ ec2_$ptr_list_t;
                   in ec_vlist: univ ec2_$val_list_t;
                   necs: integer;
                   out sts: status_$t): pinteger;
label
  100;
var
  cleanup_rec: fim_$cleanup_rec_t;
  waiters: record
    n_filled: integer;
    idx: array[1..128] of pinteger;
  end;
  ec1_vals: array[1..34] of integer32;
  ec1s: array[1..34] of ec_$eventcount_ptr_t;
  cleanup_status: status_$t;
  satisfied: integer;
  i: integer;
  n_ec1: integer;
  pid: pinteger;
  ec: ec2_$ptr_t;
  handle: linteger;
  ec1: ec_$eventcount_ptr_t;
  slot: integer;
  old_head: pinteger;
  widx: pinteger;
  w: ^ec2_waiter_t;
  nh: pinteger;
  value: integer32;
  delta: integer32;
  quit: boolean;
begin
  if necs > 128 then begin
    sts.all := ec2_$no_wait_entries;
    ec2_$wait := 0;
    return;
  end;

  sts.all := status_$ok;
  waiters.n_filled := 0;
  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    ml_$lock(ml_$ec2_lock);
    satisfied := -1;

    repeat
      n_ec1 := 2;
      pid := proc1_$current;

      { the scan }
      for i := 1 to necs do begin
        ec := ec_plist[i];
        handle := linteger(ec);
        if handle <= 16#120 then begin
          { an EC2 number }
          if handle = 0 then begin
            sts.all := ec2_$bad_eventcount;
            satisfied := i;
            goto 100;
          end;
          if handle = ec2_$always_ready_ec then begin
            satisfied := i;
            goto 100;
          end;
          if handle <= ec2_$max_registered then
            ec1 := ec2_$registered_ec1s[handle]
          else if handle < pbu_ec_index_min then begin
            sts.all := ec2_$bad_eventcount;
            satisfied := i;
            goto 100;
          end
          else begin
            slot := handle - pbu_ec_index_min;
            if not (slot in ec2_$pbu_allocated) then begin
              sts.all := ec2_$bad_eventcount;
              satisfied := i;
              goto 100;
            end;
            with ec2_$pbu_ecs[slot] do begin
              ec1 := addr(ec);
              reserved1 := reserved1 + 1;
            end;
          end;
          waiters.n_filled := i;
          waiters.idx[i] := 0;
          if n_ec1 >= 32 then begin
            sts.all := ec2_$no_wait_entries;
            satisfied := i;
            goto 100;
          end;
          n_ec1 := n_ec1 + 1;
          ec1s[n_ec1] := ec1;
          ec1_vals[n_ec1] := ec_vlist[i];
        end
        else begin
          { an eventcount's address }
          if handle >= as_$protection then begin
            sts.all := fault_$prot_violation;
            satisfied := i;
            goto 100;
          end;
          old_head := ec^.awaiters;
          ec^.awaiters := 16#FFFF;
          widx := ec2_$free_head;
          if widx = 0 then begin
            sts.all := ec2_$no_wait_entries;
            ec^.awaiters := old_head;
            satisfied := i;
            goto 100;
          end;
          w := addr(ec2_waiter_table_base[widx]);
          if old_head = 0 then begin
            ec2_$free_head := w^.next;
            old_head := widx;
            w^.next := widx;
            w^.prev := widx;
          end
          else if (old_head > 16#E0) or else
                  (ec2_waiter_table_base[old_head].proc_id = 0) then begin
            sts.all := ec2_$bad_eventcount;
            ec^.awaiters := old_head;
            satisfied := i;
            goto 100;
          end
          else begin
            ec2_$free_head := w^.next;
            w^.prev := old_head;
            w^.next := ec2_waiter_table_base[old_head].next;
            ec2_waiter_table_base[ec2_waiter_table_base[old_head].next].prev :=
              widx;
            ec2_waiter_table_base[old_head].next := widx;
          end;
          w^.proc_id := pid;
          waiters.n_filled := i;
          waiters.idx[i] := widx;
          ec^.awaiters := old_head;
          w^.wait_val := ec_vlist[i];
          if ec^.value - w^.wait_val >= 0 then begin
            satisfied := i;
            goto 100;
          end;
        end;
      end;

      { the process's wait eventcount }
      ec1s[1] := addr(ec2_$wait_ecs[pid]);
      ec1_vals[1] := ec2_$wait_ecs[pid].value + 1;
      ml_$unlock(ml_$ec2_lock);

      { the quit eventcount, and the wait }
      ec1s[2] := addr(fim_$quit_ec[proc1_$as_id]);
      ec1_vals[2] := fim_$quit_value[proc1_$as_id] + 1;
      quit := ec_$waitn(ec1s, ec1_vals, n_ec1) = 2;
      if quit then begin
        fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
        sts.all := ec2_$wait_quit;
        satisfied := 0;
      end;
      ml_$lock(ml_$ec2_lock);

      { the cleanup pass }
100:
      for i := waiters.n_filled downto 1 do begin
        ec := ec_plist[i];
        widx := waiters.idx[i];
        if widx = 0 then begin
          handle := linteger(ec);
          if (handle >= pbu_ec_index_min) and then
             (handle <= pbu_ec_index_max) then begin
            slot := handle - pbu_ec_index_min;
            with ec2_$pbu_ecs[slot] do begin
              reserved1 := reserved1 - 1;
              if slot in ec2_$pbu_allocated then
                value := ec.value
              else begin
                sts.all := ec2_$bad_eventcount;
                satisfied := i;
                next;
              end;
            end;
          end
          else if (handle = 0) or else (handle > ec2_$max_registered) then
          begin
            sts.all := ec2_$bad_eventcount;
            satisfied := i;
            next;
          end
          else
            value := ec2_$registered_ec1s[handle]^.value;
        end
        else begin
          waiters.idx[i] := 0;
          w := addr(ec2_waiter_table_base[widx]);
          if w^.next <> widx then begin
            ec2_waiter_table_base[w^.prev].next := w^.next;
            ec2_waiter_table_base[w^.next].prev := w^.prev;
            nh := w^.next;
          end
          else
            nh := 0;
          w^.next := ec2_$free_head;
          ec2_$free_head := widx;
          w^.proc_id := 0;
          if linteger(ec) >= as_$protection then begin
            sts.all := fault_$prot_violation;
            satisfied := i;
            next;
          end;
          ec^.awaiters := nh;
          value := ec^.value;
        end;
        delta := value - ec_vlist[i];
        if delta >= 0 then
          satisfied := i;
      end;
    until satisfied >= 0;

    ec2_$wait := satisfied;
    ml_$unlock(ml_$ec2_lock);
    fim_$rls_cleanup(cleanup_rec);
  end
  else begin
    { a fault: free the records recorded }
    for i := 1 to waiters.n_filled do begin
      widx := waiters.idx[i];
      if (widx <> 0) and then (widx <= 16#E0) then begin
        w := addr(ec2_waiter_table_base[widx]);
        ec2_waiter_table_base[w^.next].prev := w^.prev;
        ec2_waiter_table_base[w^.prev].next := w^.next;
        w^.prev := 0;
        w^.proc_id := 0;
        w^.next := ec2_$free_head;
        ec2_$free_head := widx;
      end;
    end;
    ml_$unlock(ml_$ec2_lock);
    fim_$signal(cleanup_status);
  end;
end;
