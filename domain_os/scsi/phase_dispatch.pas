{ scsi_phase_dispatch - start the bus phase the target asks for.

  Image addresses:
    sau9  0x3C4A6036  scsi_phase_dispatch

  Assume we're called with the SCSI spin lock held.

  - A data phase against the request's direction is padded, its status
    illegal data direction.
  - The two reserved phases crash the system.
}

procedure scsi_phase_dispatch(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                              req: scsi_req_ptr_t; phase: integer);
begin
  case phase of
    c90_phase_data_out:
      if req^.dir = scsi_$dir_out then
        scsi_start_dma(cb, tgt, req)
      else begin
        req^.result.status.all := status_$scsi_illegal_data_direction;
        scsi_xfer_pad(cb, tgt, req);
      end;
    c90_phase_data_in:
      if req^.dir = scsi_$dir_in then
        scsi_start_dma(cb, tgt, req)
      else begin
        req^.result.status.all := status_$scsi_illegal_data_direction;
        scsi_xfer_pad(cb, tgt, req);
      end;
    c90_phase_command:
      scsi_send_cdb(cb, tgt, req);
    c90_phase_status:
      scsi_status_start(cb, tgt, req);
    c90_phase_msg_out:
      scsi_msg_out(cb, tgt, req);
    c90_phase_msg_in:
      scsi_msg_in_start(cb, tgt, req);
    otherwise
      crash_system(status_$scsi_illegal_bus_phase);
  end;
end;
