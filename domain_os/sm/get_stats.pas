{ SM_$GET_STATS - return a storage module drive's counters.

  Image addresses:
    sau5  0x00E6F5D0  SM_$GET_STATS

  - The 22 bytes of the command block's drive record.  The controller
    number is not read.

  Status stored: none.
}

procedure sm_$get_stats(cnum: integer; unit: pinteger;
                        out stats: univ disk_$stats_t);
  options(val_param);
begin
  stats := sm_$cb.drive[unit].stats;
end;
