{ scsi_post_cmd - put a device's command in a slot and start it.

  Image addresses:
    sau7  0x3C4B8646  scsi_post_cmd (module-local)

  Assume we're called with scsi_$exclusion_lock held.

  - The slot's command block gets the command, the target and logical
    unit, the data's length and bus address and the direction; its bus
    address goes in the slot's outgoing mailbox, the slot records the
    command's id and device, and the start command names the slot.
  - A data transfer marks the device busy.
  - With no slot free, the adapter is asked for an interrupt when one
    is, and the bus's eventcount waited for (120 ticks, quit allowed,
    the lock released); then once more.

  Status stored:
    status_$scsi_operation_timeout: no slot was freed in time
    status_$scsi_quit_fault: a quit
}

procedure scsi_post_cmd(var t: scsi_tinfo_t; in cdb: scsi_$cdb_t;
                        pa: integer32; len: integer32; dir: integer;
                        id: integer32; out status: status_$t); internal;
type
  start_t = record
    case integer of
      1: (b: char);
      2: (f: packed record
            op: 0..3;                     { bits 7..6 }
            slot: 0..63;                  { bits 5..0 }
          end);
  end;
  mbox_ptr_t = ^scsi_mbox_t;
  slot_ptr_t = ^scsi_slot_t;
var
  cb: scsi_mb_cb_ptr_t;
  regs: scsi_mb_regs_ptr_t;
  tries: integer;
  slot: integer;
  spin: integer;
  which: integer;
  wait_value: integer32;
  quit_value: integer32;
  mbox: mbox_ptr_t;
  scb: scsi_scb_ptr_t;
  sp: slot_ptr_t;
  scb_pa: integer32;
  start: start_t;
begin
  cb := addr(scsi_$cb[t.bus]);
  regs := cb^.regs;
  for tries := 1 to 2 do begin
    slot := scsi_get_slot(t);
    if slot < 0 then begin
      { no slot free }
      regs^.cmd := scsi_mb_cmd_free_int;
      spin := 0;
      repeat
        spin := spin + 1;
      until spin = 20000;
      wait_value := cb^.ec.value + 1;
      quit_value := fim_$quit_value[proc1_$as_id] + 1;
      ml_$exclusion_stop(scsi_$exclusion_lock);
      which := ec_$wait(addr(cb^.ec), addr(time_$clockh_ec),
                        addr(fim_$quit_ec[proc1_$as_id]), wait_value,
                        time_$clockh + 120, quit_value);
      ml_$exclusion_start(scsi_$exclusion_lock);
      case which of
        0: { empty };
        1: begin
            status.all := status_$scsi_operation_timeout;
            return;
          end;
        2: begin
            status.all := status_$scsi_quit_fault;
            fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
            return;
          end;
      end;
    end
    else begin
      mbox := addr(scsi_mailboxes[slot]);
      scb := addr(scsi_scbs[slot]);
      sp := addr(cb^.slots[slot]);
      if len <> 0 then
        t.flags := t.flags + [scsi_tf_busy];
      scb_pa := integer32(scb) - integer32(addr(scsi_scbs)) + cb^.scb_base;
      mbox^.scb := scb_pa & 16#FFFFFF;
      start.f.op := scsi_mb_cmd_start;
      start.f.slot := slot;
      sp^.index := slot;
      sp^.flags := sp^.flags + [scsi_slot_in_use];
      sp^.id := id;
      sp^.scb_pa := scb_pa;
      sp^.dev := t.dev;
      os_$data_zero(scb^, 32);
      scb^.cdb := cdb;
      scb^.op := 0;
      scb^.target := t.target;
      scb^.lun := t.lun;
      scb^.len := len & 16#FFFFFF;
      scb^.data := pa & 16#FFFFFF;
      scb^.dir_in := dir = scsi_$dir_in;
      regs^.cmd := ord(start.b);
      return;
    end;
  end;
end;
