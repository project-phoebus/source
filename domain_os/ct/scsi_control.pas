{ ct_scsi_control - start a tape motion or control command on the drive.

  Image addresses:
    sau7  0x3C4852A0  ct_scsi_control (module-local)
    sau9  0x3C4779E4  ct_scsi_control (module-local)

  - op is a CT_$CONTROL operation (ct_$op_space_fwd .. ct_$op_reset) or
    the driver's own (ct_op_block_address .. ct_op_self_test); count is
    the spacing and filemark operations' count.
  - The reset is done at once; the others build ct_cmd_cdb and start it,
    outstanding until SCSI_WAIT.
  - Writing filemarks, erasing and rewinding end the transfer state
    when they succeed (ct_clear_on_ok).

  Returns:
    0: the command was started
    ct_scsi_reset's result: the reset
    status_$ct_unrecognized_action_type: any other op
    SCSI_$DO_COMMAND's status: it failed

  Status stored: none.
}

function ct_scsi_control(op: integer; count: integer): integer32; internal;
type
  byte_ptr_t = ^char;
var
  st: status_$t;
  dir: integer;
  len: integer32;
  n: integer;
  buf: byte_ptr_t;
begin
  st.all := 0;
  ct_xfer_count := 0;
  n := count;
  ct_clear_on_ok := false;
  dir := scsi_$dir_out;
  len := 0;
  ct_init_cdb;
  case op of
    ct_$op_space_fwd: begin
        ct_cmd_cdb.t.op := ct_scsi_op_space;
        ct_cmd_cdb.t.rest := ct_scsi_space_blocks;
        ct_cmd_cdb.t.len := ct_to_24(n);
      end;
    ct_$op_space_rev: begin
        ct_cmd_cdb.t.op := ct_scsi_op_space;
        ct_cmd_cdb.t.rest := ct_scsi_space_blocks;
        ct_cmd_cdb.t.len := ct_to_24(-n);
      end;
    ct_$op_file_fwd: begin
        ct_cmd_cdb.t.op := ct_scsi_op_space;
        ct_cmd_cdb.t.rest := ct_scsi_space_filemarks;
        ct_cmd_cdb.t.len := ct_to_24(n);
      end;
    ct_$op_file_rev: begin
        ct_cmd_cdb.t.op := ct_scsi_op_space;
        ct_cmd_cdb.t.rest := ct_scsi_space_filemarks;
        ct_cmd_cdb.t.len := ct_to_24(-n);
      end;
    ct_$op_write_filemark: begin
        ct_cmd_cdb.t.op := ct_scsi_op_write_filemarks;
        ct_cmd_cdb.t.len := ct_to_24(n);
        ct_clear_on_ok := true;
      end;
    ct_$op_erase: begin
        ct_cmd_cdb.t.op := ct_scsi_op_erase;
        ct_cmd_cdb.t.rest := ct_scsi_erase_long;
        ct_clear_on_ok := true;
      end;
    ct_$op_retension: begin
        ct_cmd_cdb.t.op := ct_scsi_op_load_unload;
        ct_cmd_cdb.b[4] := chr(ct_scsi_retension);
      end;
    ct_$op_rewind: begin
        ct_cmd_cdb.t.op := ct_scsi_op_rewind;
        ct_clear_on_ok := true;
      end;
    ct_$op_reset: begin
        ct_scsi_control := ct_scsi_reset;
        return;
      end;
    ct_op_block_address: begin
        ct_cmd_cdb.t.op := ct_scsi_op_request_block_address;
        ct_cmd_cdb.b[4] := chr(3);
        len := 3;
        dir := scsi_$dir_in;
        buf := addr(ct_mode.b[1]);
      end;
    ct_op_mode_sense: begin
        ct_cmd_cdb.t.op := ct_scsi_op_mode_sense;
        ct_cmd_cdb.b[4] := chr(4);
        len := 4;
        dir := scsi_$dir_in;
        buf := addr(ct_mode.b[0]);
      end;
    ct_op_mode_select: begin
        ct_cmd_cdb.t.op := ct_scsi_op_mode_select;
        ct_cmd_cdb.b[4] := chr(4);
        len := 4;
        dir := scsi_$dir_out;
        buf := addr(ct_mode.b[4]);
      end;
    ct_op_self_test: begin
        ct_cmd_cdb.t.op := ct_scsi_op_send_diagnostic;
        ct_cmd_cdb.b[1] := chr(ct_scsi_self_test);
      end;
    otherwise begin
      st.all := status_$ct_unrecognized_action_type;
    end;
  end;
  if st.all = 0 then begin
    scsi_$do_command(ct_handle, ct_cmd_cdb, buf^, len, dir, ct_req_id, st);
    if st.all = 0 then
      ct_busy := true;
    ct_xfer_count := count;
  end
  else
    ct_busy := false;
  ct_scsi_control := st.all;
end;
