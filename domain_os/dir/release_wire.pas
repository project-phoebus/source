{ dir_$release_wire - unwire a handle's wired page.

  Image addresses:
    sau2  0x00E4B838  dir_$release_wire

  - A handle with no page wired (max_slots 2) crashes the system.

  Status stored: none.
}

procedure dir_$release_wire(var handle: dir_$handle_t);
  internal;
begin
  if handle.max_slots = 2 then
    crash_system(status_$naming_internal_error);

  handle.max_slots := 2;
  wp_$unwire(handle.wired_page);
end;
