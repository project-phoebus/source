{ COLOR6_$DISSOC - dissociate the board from the current process.

  Image addresses:
    sau7  0x3C483B18  COLOR6_$DISSOC

  - The unit's association is dropped (color6_release), under the SMD
    request lock.

  Status stored:
    status_$ok: always
}

procedure color6_$dissoc(dcte: color6_$dcte_ptr_t; out status: status_$t);
  options(val_param);
var
  info: color6_$info_ptr_t;
begin
  info := dcte^.info;
  ml_$lock(ml_$smd_request_lock);
  color6_release(info);
  ml_$unlock(ml_$smd_request_lock);
  status.all := status_$ok;
end;
