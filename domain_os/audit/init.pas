{ AUDIT_$INIT - set up the audit trail at boot.

  Image addresses:
    sau2  0x00E70AFC  AUDIT_$INIT

  - The module's state is cleared, the lock and the eventcount
    initialized, and the logging started in super mode.
  - If that fails three messages are printed and the trail marked
    corrupted (every event is logged).
  - The map gives its address the second name AUDIT_$PROC_START.
  - The routine ends with a second ACL_$ENTER_SUPER, so the boot
    process's super-mode count is left at 2.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of AUDIT_$INIT no object explains

  The SAU2 frame holds the status and the `for' index's slot
  (a register-held local keeps its slot): 6
  bytes, 8 when rounded.  The stand-in unused_c holds the other 4: a
  local the source declared and never used, or a temporary (a `for'
  loop has no hidden cost). }

procedure audit_$init;
var
  status: status_$t;
  i: integer;
  unused_c: integer32;                    { stand-in, see the TODO }
begin
  audit_$wired := get_wired;
  audit_$enabled := false;
  audit_$corrupted := false;
  audit_$server_running := false;
  audit_$list_uid := uid_$nil;
  audit_$list_count := 0;
  audit_$flags := [];
  audit_$log_file_uid := uid_$nil;
  audit_$buffer_base := 0;
  audit_$buffer_size := 0;
  for i := 1 to 64 do
    audit_$suspend_count[i] := 0;
  audit_$server_pid := 0;
  audit_$lock_id := 0;

  ml_$exclusion_init(audit_$wired^.lock);
  ec_$init(audit_$wired^.ec);
  acl_$enter_super;
  audit_$start_logging(status);

  if status.all <> status_$ok then begin
    vfmt_$write2('%/%/%/%/Warning, could not start audit trail: 0x%8zulh%.',
                 status, 0);
    vfmt_$write2('All events will be logged.%.', 0, 0);
    vfmt_$write2('Only audit administrators will be allowed to login.%.',
                 0, 0);
    audit_$corrupted := true;
  end;

  { ENTER_SUPER again (above) }
  acl_$enter_super;
end;
