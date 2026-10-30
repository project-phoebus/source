{ PCHIST_$INIT - initialize the profiler's exclusion lock.

  Image addresses:
    sau2  0x00E32394  PCHIST_$INIT

  - The lock is reached by its absolute address (another section's
    block).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure pchist_$init;
begin
  ml_$exclusion_init(pchist_$lock);
end;
