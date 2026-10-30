{ FLOP_$BOOT - boot from the floppy: map the boot shell, return its entry.

  Image addresses:
    sau2  0x00E3254C  FLOP_$BOOT
    sau2  0x00E323A8  flop_$boot_errchk (nested)

  - The floppy is mounted at /flp (the nested flop_$mount_floppy), and
    /flp/sys/boot_shell locked and mapped twice: to read its header,
    then at the address it gives; its entry point is returned.
  - After every step but the resolve, the nested flop_$boot_errchk
    reports a failure on the boot console; the first failure ends it.
  - The result is whether the status is ok.

  Status stored:
    status_$ok: the boot shell was mapped
    the failing step's status: flop_$mount_floppy's, NAME_$RESOLVE's,
      FILE_$LOCK's, MST_$MAP's, MST_$UNMAP's or MST_$MAP_AT's
}

[section(os_init_proc, os_init_data)]
function flop_$boot(out entry_point: integer32;
                    out status_ret: status_$t): boolean;
label
  done;
var
  header: flop_$header_t;
  boot_shell_uid: uid_$t;
  mapped_va: integer32;
  mapped_addr: flop_$header_ptr_t;
  lock_info: integer32;
  map_info: integer32;

  { flop_$boot_errchk - report a failed boot step on the console.

    - Nested in FLOP_$BOOT: OS_$BOOT_ERRCHK prints the message (and
      "- trying normal shell") when the parent's status is not ok.

    Status stored: none.
  }

  procedure flop_$boot_errchk(in msg: univ crash_$chars_t);
  begin
    discard(os_$boot_errchk(msg, '- trying normal shell', 21, status_ret));
  end;

%include 'flop/mount_floppy.pas';           { flop_$mount_floppy }

begin
  flop_$mount_floppy(status_ret);
  flop_$boot_errchk('bad floppy mount%');
  if status_ret.all <> status_$ok then
    goto done;

  name_$resolve('/flp/sys/boot_shell', 19, boot_shell_uid, status_ret);
  if status_ret.all <> status_$ok then
    goto done;

  file_$lock(boot_shell_uid, 1, 4, false, lock_info, status_ret);
  flop_$boot_errchk('can''t lock boot shell%');
  if status_ret.all <> status_$ok then
    goto done;

  { map it to read the header }
  mapped_addr := mst_$map(boot_shell_uid, 0, 16#100000, 7, 0, true,
                          map_info, status_ret);
  flop_$boot_errchk('can''t map boot shell%');
  if status_ret.all <> status_$ok then
    goto done;

  header := mapped_addr^;
  mapped_va := integer32(mapped_addr);
  mst_$unmap(boot_shell_uid, mapped_va, map_info, status_ret);
  flop_$boot_errchk('can''t unmap boot shell%');
  if status_ret.all <> status_$ok then
    goto done;

  { map it where it asks to be }
  mst_$map_at(header[1], boot_shell_uid, 0, 16#100000, 7, 0, false,
              map_info, status_ret);
  flop_$boot_errchk('can''t map at indicated address%');
  if status_ret.all <> status_$ok then
    goto done;

  entry_point := header[2];

done:
  flop_$boot := status_ret.all = status_$ok;
end;
