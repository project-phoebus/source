{ ethernet_do_cmd - give the adapter a command and wait for its reply.

  Image addresses:
    sau7  0x3C4914C2  ethernet_do_cmd
    sau8  0x03C84CBE  ethernet_do_cmd
    sau9  0x3C4808BE  ethernet_do_cmd

  - Under the unit's command lock, one command at a time.  The reply is
    copied into the command's block; a command the adapter did not take
    is no longer pending.

  Status stored:
    ethernet_start_cmd's status: the block did not go out
    ethernet_wait_cmd's status: it did
}

function ethernet_do_cmd(u: ethernet_$unit_ptr_t; pcb: ethernet_$pcb_ptr_t;
                         reply_cmd: integer; out status: status_$t): boolean;
  internal;
var
  st: status_$t;
begin
  ml_$exclusion_start(u^.cmd_lock);
  ethernet_start_cmd(u, pcb, reply_cmd, st);
  if st.all = status_$ok then
    ethernet_wait_cmd(u, st)
  else
    u^.flags := u^.flags - [eth_unit_cmd_pending];
  ml_$exclusion_stop(u^.cmd_lock);
  status := st;
  ethernet_do_cmd := status.all = status_$ok;
end;
