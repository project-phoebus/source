{ scsi_msg_in - act on a message from the connected target.

  Image addresses:
    sau9  0x3C4A5C10  scsi_msg_in

  Assume we're called with the SCSI spin lock held.

  - An IDENTIFY or COMMAND COMPLETE ends the message phase's business
    (the target's state scsi_ts_msg_done); SAVE DATA POINTER finishes the
    data transfer so far; a synchronous transfer request is answered
    within the bus's limits, or rejected; a MESSAGE REJECT of the
    driver's request makes the target asynchronous.
  - The message is kept as the target's last; the next message out is a
    MESSAGE REJECT (with attention raised) or a NOP; the message is then
    accepted.
  - Any other message crashes the system.
}

procedure scsi_msg_in(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                      req: scsi_req_ptr_t; in msg: univ scsi_msg_buf_t;
                      count: integer);
var
  reject: boolean;
  period: linteger;
  i: integer;
begin
  reject := false;
  if (msg[0] & scsi_msg_identify) <> 0 then
    tgt^.state := scsi_ts_msg_done
  else
    case msg[0] of
      scsi_msg_command_complete: begin
        tgt^.state := scsi_ts_msg_done;
      end;

      { A synchronous data transfer request: its offset (msg[4]) and
        period (msg[3], in 4 ns units). }
      scsi_msg_extended: begin
        if msg[2] = scsi_xmsg_sdtr then begin
          if msg[4] = 0 then
            tgt^.sync_state := scsi_sync_async
          else if msg[4] > cb^.max_offset then
            reject := true
          else
            tgt^.sync_offset := msg[4];
          period := msg[3] * 4;
          if (period > cb^.max_period)
             or else (period < cb^.min_period) then begin
            tgt^.sync_offset := 0;
            reject := true;
          end
          else begin
            tgt^.sync_period :=
              ((100 * period div cb^.clock_ns + 5) div 10 + 5) div 10;
            tgt^.sync_state := scsi_sync_agreed;
          end;
        end
        else begin
          crash_system(status_$scsi_unknown_message);
          reject := true;
        end;
        tgt^.state := scsi_ts_msg_in_more;
      end;

      scsi_msg_save_data_pointer: begin
        scsi_finish_data(cb, req);
        tgt^.state := scsi_ts_msg_in_more;
      end;

      scsi_msg_restore_pointers, scsi_msg_disconnect, scsi_msg_nop,
      scsi_msg_linked_complete, scsi_msg_linked_complete_flag: begin
        tgt^.state := scsi_ts_msg_in_more;
      end;

      scsi_msg_reject: begin
        if tgt^.sync_state = scsi_sync_requested then
          tgt^.sync_state := scsi_sync_async
        else begin
          crash_system(status_$scsi_unknown_message);
          reject := true;
        end;
        tgt^.state := scsi_ts_msg_in_more;
      end;

      otherwise begin
        crash_system(status_$scsi_unknown_message);
        reject := true;
        tgt^.state := scsi_ts_msg_in_more;
      end;
    end;

  for i := 0 to count - 1 do
    tgt^.last_msg[i] := msg[i];
  tgt^.last_msg_len := count;
  if reject then begin
    cb^.msg[0] := scsi_msg_reject;
    cb^.msg_count := 1;
    cb^.send_atn := true;
  end
  else begin
    cb^.msg[0] := scsi_msg_nop;
    cb^.msg_count := 1;
  end;
  if cb^.send_atn then begin
    cb^.send_atn := false;
    cb^.regs^.cmd := c90_cmd_set_atn;
  end;
  cb^.regs^.cmd := c90_cmd_msg_accepted;
end;
