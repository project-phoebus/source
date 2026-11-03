{ sm_c_$reinit - bring a volume's SM_C drive up again after errors.

  Image addresses:
    sau3  0x00E6F616  sm_c_$reinit (module-local)
    sau5  0x00E7517C  sm_c_$reinit (module-local)

  - The drive comes up with the volume's own geometry; the unit's status
    word and the current request are put back, and sm_c_$start_drive's
    status is dropped.

  Status stored: none.
}

procedure sm_c_$reinit(in vol: disk_$volume_t); internal;
var
  saved_req: disk_$io_req_ptr_t;
  saved_status: sm_c_$status_t;
  pvlabel: disk_$pvlabel_info_t;
  drv_flags: pinteger;
begin
  saved_req := sm_c_req;
  sm_c_req := nil;
  with sm_$cb.c_unit[vol.dev_unit] do begin
    saved_status := status;
    discard(sm_c_$start_drive(vol.dev_unit, sm_c_dcte, vol.addr_start,
                              vol.sec_per_track, vol.num_heads, pvlabel,
                              drv_flags));
    status := saved_status;
  end;
  sm_c_req := saved_req;
end;
