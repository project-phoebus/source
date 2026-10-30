{ ACL_$IMAGE - an ACL object's version-5 image, under the ACL lock.

  Image addresses:
    sau2  0x00E47DF6  ACL_$IMAGE

  - Under ml_$acl_lock and a cleanup handler, acl_$image_internal with
    the caller's arguments.

  Status stored:
    acl_$image_internal's status: no fault
    fim_$cleanup's status: a fault came back through the handler
}

procedure acl_$image(in source_uid: uid_$t; in buffer_len: integer;
                     in flag: boolean; var image: univ acl_$cache_slot_t;
                     out len_out: integer; var data_out: acl_$prot_data_t;
                     out status_ret: status_$t);
var
  cleanup: fim_$cleanup_rec_t;
  status: status_$t;
  flag_out: boolean;
begin
  ml_$lock(ml_$acl_lock);

  status := fim_$cleanup(cleanup);
  if status.all = fault_$cleanup_set then begin
    acl_$image_internal(source_uid, buffer_len, flag, image, len_out,
                        data_out, flag_out, status);
    fim_$rls_cleanup(cleanup);
  end
  else
    fim_$pop_signal(cleanup);

  ml_$unlock(ml_$acl_lock);
  status_ret := status;
end;
