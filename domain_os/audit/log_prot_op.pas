{ audit_$log_prot_op - log a protection change (a fragment of DIR).

  Image addresses:
    sau2  0x00E4AF28  audit_$log_prot_op (module-local)

  - Event 16#14 of class 4, with a 70-byte record: the 44-byte
    protection data, the object's, the subject's and the ACL's UIDs and
    the protection flags.
  - The event's flag is 1 when the operation failed.
  - In DIR's code segment (.TEXT), its first routine, included by
    ../dir/dir.pas.

  Status stored: none.
}

{ TODO(pascal) bytes of two DIR event loggers' frames no object explains

  The five loggers (audit/log_*_op.pas) have their event UID at the top
  of the frame and their event data 8-aligned below it (SAU2);
  audit_$log_dir_op's, _$log_link_op's and _$log_cname_op's frames are
  then exactly their locals, the register-held lengths and pointers
  keeping slots.  audit_$log_prot_op has 6 bytes
  no instruction addresses above success_flag, audit_$log_mount_op 4
  (the stand-ins unused_5e and unused_2c): their entry loads of a
  by-value word (prot_flags) and longword (extra) are parameters, not
  locals with slots, so the slots' owners are not known. }

procedure audit_$log_prot_op(status: status_$t; in uid: uid_$t;
                             in prot_data: univ audit_$prot_data_t;
                             in acl_uid: uid_$t; in subject_uid: uid_$t;
                             prot_flags: integer); internal;
type
  prot_event_data_t = record
    prot_data: audit_$prot_data_t;        { 0x00 }
    dir_uid: uid_$t;                      { 0x2C }
    subject_uid: uid_$t;                  { 0x34 }
    acl_uid: uid_$t;                      { 0x3C }
    prot_flags: integer;                  { 0x44 }
  end;
var
  ev: audit_$event_uid_t;
  data: prot_event_data_t;
  unused_5e: array[1..3] of integer;      { stand-in }
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := 16#14;
  ev.reserved := 0;
  data.prot_data := prot_data;
  data.dir_uid := uid;
  data.subject_uid := subject_uid;
  data.acl_uid := acl_uid;
  data.prot_flags := prot_flags;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, 16#46);
end;
