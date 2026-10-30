{ PROC2_$GET_CR_REC - the creation record's UIDs from an EC2 handle.

  Image addresses:
    sau2  0x00E4015C  PROC2_$GET_CR_REC

  - The handle's level-1 eventcount gives the process-table index; a
    bound process or a zombie hands back its parent and own UIDs.

  Status stored:
    status_$ok: the entry is bound or a zombie
    proc2_$uid_not_found: it is not, or EC2_$GET_EC1_ADDR failed
}

procedure proc2_$get_cr_rec(in ec_handle: univ_ptr;
                            out parent_uid: uid_$t;
                            out proc_uid: uid_$t;
                            out status_ret: status_$t);
var
  status: status_$t;
  handle: ec2_$ptr_t;
  idx: integer;
begin
  handle := ec_handle;
  idx := (ec2_$get_ec1_addr(handle, status)
          - integer32(addr(proc2_$ec))) div 24 + 1;
  if (status.all <> status_$ok)
     or else not ((proc2_pf_bound
                     in proc2_$info_table[idx].flags.bits)
                  or else (proc2_pf_zombie
                     in proc2_$info_table[idx].flags.bits)) then
    status_ret.all := proc2_$uid_not_found
  else begin
    parent_uid := proc2_$info_table[idx].parent_uid;
    proc_uid := proc2_$info_table[idx].uid;
    status_ret.all := status_$ok;
  end;
end;
