{ VOLX_$GET_INFO - a volume's free and total blocks and its directory.

  Image addresses:
    sau2  0x00E6B5C6  VOLX_$GET_INFO

  Status stored:
    status_$ok: the counts and the directory's UID were returned
    status_$volume_logical_vol_not_mounted: the volume's BAT is not
      mounted
    bat_$n_free's status: any other failure
}

procedure volx_$get_info(vol_idx: integer; out dir_uid_ret: uid_$t;
                         out free_blocks: integer32;
                         out total_blocks: integer32;
                         out status: status_$t);
begin
  bat_$n_free(vol_idx, free_blocks, total_blocks, status);

  if status.all = status_$ok then
    dir_uid_ret := volx_$table[vol_idx].e_dir_uid;

  if status.all = status_$bat_not_mounted then
    status.all := status_$volume_logical_vol_not_mounted;
end;
