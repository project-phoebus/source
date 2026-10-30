{ proc2_$cleanup_handlers_internal - run the cleanups a dying process's
  subsystems registered.

  Image addresses:
    sau2  0x00E3E808  proc2_$cleanup_handlers_internal (module-local)

  - Each subsystem whose bit is set in the entry's cleanup_flags
    (PROC2_$SET_CLEANUP) releases the process's address space, in a
    fixed order.

  Status stored: none.
}

procedure proc2_$cleanup_handlers_internal(entry: proc2_info_t); internal;
var
  status: status_$t;
  asid: integer;
begin
  asid := entry.asid;
  if proc2_$cleanup_lpr in entry.cleanup_flags then
    lpr_$release(false, status);
  if proc2_$cleanup_mt in entry.cleanup_flags then
    mt_$release(-1, 1, status);
  if proc2_$cleanup_disk in entry.cleanup_flags then
    disk_$unassign_all;
  if proc2_$cleanup_time in entry.cleanup_flags then
    time_$release;
  if proc2_$cleanup_ct in entry.cleanup_flags then
    ct_$release(0, true, status);
  if proc2_$cleanup_pbu in entry.cleanup_flags then
    pbu_$free_asid(asid);
  if proc2_$cleanup_msg in entry.cleanup_flags then
    msg_$free_asid(asid);
  if proc2_$cleanup_gpu in entry.cleanup_flags then
    gpu_$term;
  if proc2_$cleanup_net_io in entry.cleanup_flags then
    net_io_$free_asid(asid);
  if proc2_$cleanup_pchist in entry.cleanup_flags then
    pchist_$unix_profil_cntl(pchist_$profil_disable, 0, 0, 0, 0, status);
  if proc2_$cleanup_scsi in entry.cleanup_flags then
    scsi_$free_asid(asid);
  if proc2_$cleanup_mac_os in entry.cleanup_flags then
    mac_os_$proc2_cleanup(asid);
  if proc2_$cleanup_xns_idp in entry.cleanup_flags then
    xns_idp_$proc2_cleanup(asid);
end;
