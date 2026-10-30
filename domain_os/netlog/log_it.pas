{ NETLOG_$LOG_IT - log one network event, if its kind is logged.

  Image addresses:
    sau2  0x00E71B38  NETLOG_$LOG_IT

  - The entry is written under the module's spin lock; a page that
    reaches 39 entries goes to the sender, and NETLOG_$EC is advanced
    after the lock.
  - The timestamp is the clock's low32.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_18)

  In the SAU2 frame the UID's copy, the clock, token and need_advance's
  slot account for 0x14 bytes.  The 4 below are the stand-in unused_18.
  Such bytes may be the `with' statement's temporary, the element's
  address (whether the compiler reserves a slot for it is not settled);
  if it does, the stand-in goes. }

procedure netlog_$log_it(kind: integer; uid: uid_$t; param3: integer;
                         param4: integer; param5: integer; param6: integer;
                         param7: integer; param8: integer);
  options(val_param);
var
  timestamp: time_$clock_t;
  token: integer;
  need_advance: boolean;
  unused_18: integer32;                   { the stand-in (TODO) }
begin
  if not (kind in netlog_$kinds) then
    return;

  need_advance := false;
  token := ml_$spin_lock(spin_lock);
  time_$clock(timestamp);

  { the next entry of the filling page }
  page_counts[current_buf_index] := page_counts[current_buf_index] + 1;
  with netlog_$page_ptr_t(current_buf_ptr)^
         [page_counts[current_buf_index]] do begin
    e_kind := kind;
    e_process_id := proc1_$current;
    e_timestamp := timestamp.low32;
    e_uid := uid;
    e_param3 := param3;
    e_param4 := param4;
    e_param5 := param5;
    e_param6 := param6;
    e_param7 := param7;
    e_param8 := param8;
  end;

  { a full page goes to the sender }
  if page_counts[current_buf_index] = netlog_entries_per_page then begin
    send_page_index := current_buf_index;
    netlog_$done_cnt := netlog_$done_cnt + 1;
    current_buf_index := 3 - current_buf_index;
    page_counts[current_buf_index] := 0;
    need_advance := true;
    current_buf_ptr := buffer_va[current_buf_index];
  end;

  ml_$spin_unlock(spin_lock, token);
  if need_advance then
    ec_$advance(netlog_$ec);
end;
