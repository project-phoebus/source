{ TIME_$CANCEL - cancel a pending TIME_$ADVANCE.

  Image addresses:
    sau2  0x00E164A4  TIME_$CANCEL

  - The element is taken off the real-time queue.  If it had fired
    meanwhile, the eventcount is waited for to reach wait_value, so the
    advance is consumed; any other failure crashes the system.

  Status stored:
    status_$ok: canceled, or already fired
}

procedure time_$cancel(wait_value: integer32;
                       var elem: time_$queue_elem_t;
                       out status: status_$t);
var
  ec: ec_$eventcount_ptr_t;
begin
  time_$q_remove_elem(time_$rteq, elem, status);
  if status.all = time_$q_elem_not_in_use then begin
    { it fired; consume the advance }
    ec := elem.callback_arg;
    discard(ec_$wait(ec, addr(ec_$nil_ec), addr(ec_$nil_ec), wait_value,
                     0, 0));
    status.all := status_$ok;
  end
  else if status.all <> status_$ok then
    crash_system(status);
end;
