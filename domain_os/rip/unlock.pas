{ rip_$unlock - give back the RIP lock.

  Image addresses:
    sau2  0x00E154C4  rip_$unlock (module-local)

  - The reverse of rip_$lock: the exclusion record left first, then the
    process lock.

  Status stored: none.
}

procedure rip_$unlock; internal;
begin
  ml_$exclusion_stop(rip_$exclusion);
  proc1_$clr_lock(ml_$area_lock);
end;
