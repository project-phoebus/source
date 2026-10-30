{ SM_C_$GET_STATS - return an SM_C drive's counters.

  Image addresses:
    sau5  0x00E7534C  SM_C_$GET_STATS

  - cnum is not read.

  Status stored: none.
}

procedure sm_c_$get_stats(cnum: integer; unit: pinteger;
                          out stats: univ disk_$stats_t);
  options(val_param);
begin
  stats := sm_$cb.c_unit[unit].stats;
end;
