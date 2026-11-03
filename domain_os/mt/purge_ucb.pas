{ MT_PURGE_UCB - empty a tape unit's request queue.

  Image addresses:
    sau3  0x00E6FC08  MT_PURGE_UCB
    sau5  0x00E75770  MT_PURGE_UCB

  - Only with the unit's flushing member set; each block is purged with
    release (MT_$PURGE_PB), and the member cleared after.
  - UCB, the unit control block, is Apollo's word in the name.

  Status stored: none.
}

procedure mt_purge_ucb;
begin
  with mt_$scb.units[unit] do begin
    flags.bits := flags.bits + [mt_unit_flushing];
    while queue.head <> nil do
      mt_$purge_pb(unit, mt_$deq(queue), true);
    flags.bits := flags.bits - [mt_unit_flushing];
  end;
end;
