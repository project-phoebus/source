{ EC2_$WAKEUP - wake the waiters of a level-2 eventcount whose values
  have been reached.

  Image addresses:
    sau2  0x00E4285A  EC2_$WAKEUP

  - Under a cleanup handler and the EC2 lock the eventcount's waiter
    ring is walked once round, each waiter reached getting its process's
    wait eventcount advanced.  A fault unlocks and passes the fault on.

  Status stored:
    status_$ok: the waiters were woken
    ec2_$bad_eventcount: the ring's head is beyond the table, or free
}

{ TODO(pascal) four frame bytes of EC2_$WAKEUP hold nothing

  The cleanup record and status, the three register-held locals and the
  `with' temporary make 40 of the frame's 44 bytes; the stand-in
  unused_2c holds the other four.  A fourth 4-byte local would explain
  it.  Not settled. }

procedure ec2_$wakeup(in ec: ec2_$eventcount_t; out status: status_$t);
var
  cleanup_rec: fim_$cleanup_rec_t;
  cleanup_status: status_$t;
  value: integer32;
  w: pinteger;
  first: pinteger;
  unused_2c: integer32;                   { TODO above }
begin
  status.all := status_$ok;
  cleanup_status := fim_$cleanup(cleanup_rec);
  if cleanup_status.all = fault_$cleanup_set then begin
    ml_$lock(ml_$ec2_lock);
    value := ec.value;
    w := ec.awaiters;

    if w <> 0 then
      if (w <= 16#E0) and then
         (ec2_waiter_table_base[w].proc_id <> 0) then begin
        first := w;
        repeat
          with ec2_waiter_table_base[w] do begin
            w := next;
            if value - wait_val >= 0 then
              ec_$advance(ec2_$wait_ecs[proc_id]);
          end;
        until w = first;
      end
      else
        status.all := ec2_$bad_eventcount;

    ml_$unlock(ml_$ec2_lock);
    fim_$rls_cleanup(cleanup_rec);
  end
  else begin
    ml_$unlock(ml_$ec2_lock);
    fim_$signal(cleanup_status);
  end;
end;
