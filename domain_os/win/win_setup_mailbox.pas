{ WIN_SETUP_MAILBOX - put the block being set up in the next outgoing
  mailbox.

  Image addresses:
    sau7  0x3C41B9A8  WIN_SETUP_MAILBOX

  - A mailbox still in use makes the controller interrupt when one is
    free (win7_ctl_mbox_free_int), and the routine waits up to 200
    ticks for WIN7_$INT's advance of win7_mbox_ec.
  - start_cmd is the start command for the mailbox, the next index
    taken round from 61 to 0; the block is marked in its mailbox.

  Status stored:
    status_$ok: the block is in the mailbox
    status_$disk_controller_timeout: no mailbox came free
    status_$disk_driver_logic_error: the mailbox is still in use after
      the interrupt (the block is put in it all the same)
}

procedure win_setup_mailbox(in out ctlr: win7_$ctlr_t;
                            out start_cmd: integer32;
                            out status: status_$t);
var
  p: win7_$iopb_ptr_t;
  wait_value: integer32;
  unit: integer;
  tmp: win7_$bytes_t;
begin
  status.all := status_$ok;
  p := ctlr.cur;
  if ctlr.mbox^.out[ctlr.mbox_index].status <> 0 then begin
    wait_value := win7_mbox_ec.value + 1;
    unit := p^.info^.unit;
    win_send_command(false, win7_ctl_mbox_free_int, unit, ctlr, status);
    if ec_$wait(addr(win7_mbox_ec), addr(time_$clockh_ec),
                addr(ec_$nil_ec), wait_value, time_$clockh + 200,
                0) <> 0 then begin
      status.all := status_$disk_controller_timeout;
      ctlr.cur^.info^.in_mbox := false;
      return;
    end;
    if ctlr.mbox^.out[ctlr.mbox_index].status <> 0 then
      status.all := status_$disk_driver_logic_error;
  end;

  { the block's bus address and length into the mailbox }
  tmp.l := p^.info^.phys;
  ctlr.mbox^.out[ctlr.mbox_index].lo := tmp.b3;
  ctlr.mbox^.out[ctlr.mbox_index].mid := tmp.b2;
  ctlr.mbox^.out[ctlr.mbox_index].hi := tmp.b1;
  ctlr.mbox^.out[ctlr.mbox_index].status := p^.info^.length;
  start_cmd := ctlr.mbox_index ! win7_ctl_start;
  ctlr.mbox_index := ctlr.mbox_index + 1;
  if ctlr.mbox_index > 61 then
    ctlr.mbox_index := 0;
  ctlr.cur^.info^.in_mbox := true;
end;
