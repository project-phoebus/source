{ SCSI_$INT - handle the host adapter's interrupt.

  Image addresses:
    sau7  0x3C4B8C0C  SCSI_$INT

  - Under the spin lock, the incoming mailbox the interrupt status
    names: an ended command block is found among the bus's slots by its
    bus address (none counts a spurious interrupt), and its device's
    record gets the command's id, its status (from the adapter's error
    code) and SCSI status code; the end of the command waited for (or
    any, with none) advances the device's eventcount.
  - A freed outgoing mailbox advances the bus's eventcount; an
    unsolicited report gives its device's record its status and
    advances the device's reset eventcount.  Any other code crashes the
    system.
  - The interrupt is acknowledged and the adapter's interrupt and DMA
    turned on again; the eventcount is advanced after.

  Returns:
    true: the interrupt was the adapter's

  Status stored: none.
}

function scsi_$int(cb: scsi_mb_cb_ptr_t): boolean;
type
  ec_ptr_t = ^ec_$eventcount_t;
var
  adv: ec_ptr_t;
  token: pinteger;
  regs: scsi_mb_regs_ptr_t;
  mb: scsi_mbox_t;
  u: scsi_mb_unsol_t;
  found: boolean;
  i: integer;
  dev: integer;
  id: integer32;
  slot: integer;
  t: scsi_tinfo_ptr_t;
  scb: scsi_scb_ptr_t;
begin
  adv := nil;
  token := ml_$spin_lock(scsi_lock);
  regs := cb^.regs;
  cb^.int_kind := rshft(regs^.int, 6);
  cb^.int_mbox := regs^.int & 16#3F;
  mb := scsi_mailboxes[cb^.int_mbox + scsi_mb_in_base];
  case mb.status of
    scsi_mb_done, scsi_mb_done_error, scsi_mb_done_aborted: begin
        found := false;
        for i := 0 to scsi_mb_last_slot do
          if scsi_slot_in_use in cb^.slots[i].flags then
            if mb.scb = (cb^.slots[i].scb_pa & 16#FFFFFF) then begin
              dev := cb^.slots[i].dev;
              id := cb^.slots[i].id;
              slot := cb^.slots[i].index;
              cb^.slots[i].flags := cb^.slots[i].flags - [scsi_slot_in_use];
              found := true;
              exit;
            end;
        if found then begin
          t := addr(scsi_$tinfo_list[dev]);
          scb := addr(scsi_scbs[slot]);
          t^.scsi_status := scsi_$st_other;
          t^.flags := t^.flags - [scsi_tf_busy];
          t^.status.all := scsi_map_vue(scb^.vue);
          case scb^.status & 16#1E of
            0: begin
                t^.scsi_status := scsi_$st_good;
              end;
            2: begin
                t^.scsi_status := scsi_$st_check_condition;
              end;
            4: begin
                t^.scsi_status := scsi_$st_condition_met;
              end;
            8: begin
                t^.scsi_status := scsi_$st_busy;
              end;
            16: begin
                t^.scsi_status := scsi_$st_intermediate;
              end;
            24: begin
                t^.scsi_status := scsi_$st_reservation_conflict;
              end;
          end;
          t^.last_id := id;
          if (id >= t^.wait_id) or (t^.wait_id = 0) then begin
            t^.wait_id := 0;
            adv := addr(t^.done_ec);
            t^.flags := t^.flags + [scsi_tf_done];
          end;
          t^.done_count := t^.done_count + 1;
        end
        else
          scsi_$spurious_ints := scsi_$spurious_ints + 1;
      end;
    scsi_mb_freed: begin
        adv := addr(cb^.ec);
      end;
    scsi_mb_unsolicited: begin
        u.all := mb.scb;
        for i := 0 to scsi_max_dev do
          with scsi_$tinfo_list[i] do
            if (u.target = target) and (u.lun = lun) then begin
              status.all := scsi_map_vue(u.code);
              scsi_status := scsi_$st_good;
              adv := addr(reset_ec);
              done_count := done_count + 1;
              exit;
            end;
      end;
    otherwise begin
        crash_system(status_$scsi_hardware_failure);
      end;
  end;
  cb^.int_count := cb^.int_count + 1;
  regs^.int := scsi_mb_int_ack;
  regs^.ctl := scsi_mb_ctl_run;
  if adv <> nil then
    ec_$advance_without_dispatch(adv^);
  ml_$spin_unlock(scsi_lock, token);
  scsi_$int := true;
end;
