{ rip_$lock - take the RIP lock.

  Image addresses:
    sau2  0x00E154A4  rip_$lock (module-local)

  - The process lock ml_$area_lock is set, then the routing table's
    exclusion record entered.

  Status stored: none.
}

procedure rip_$lock; internal;
begin
  proc1_$set_lock(ml_$area_lock);
  ml_$exclusion_start(rip_$exclusion);
end;
