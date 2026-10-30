{ GPU_$INIT - initialize the graphics processor.

  Image addresses:
    sau2  0x00E707FC  GPU_$INIT
    sau5  0x00E73BD2  GPU_$INIT

  - Without `gpu_driver' (base/config.ins.pas; the SAU2) the routine only
    stores status_$gpu_device_not_present.
  - The first process makes the page table, a new mapped file, under the
    driver's lock; a table another process made meanwhile clears that
    attempt's status.
  - The process's page limits are set to 256, and GPU's cleanup handler
    (bit 9) set, so GPU_$TERM runs when it ends.

  Status stored:
    status_$ok: the processor was opened for the process
    status_$gpu_already_initialized: the process opened it already
    status_$gpu_device_not_present: there is no processor
    gpu_$lock's, file_$create's or mst_$maps's status: the page table
      could not be made
}

procedure gpu_$init(out status_ret: status_$t);
%if gpu_driver %then
var
  table: gpu_page_table_ptr_t;
  file_uid: uid_$t;
  map_info: integer32;
%endif
begin
%if gpu_driver %then
  status_ret.all := status_$ok;
  if page_max[proc1_$current] > 0 then
    status_ret.all := status_$gpu_already_initialized
  else if not gpu_$present then
    status_ret.all := status_$gpu_device_not_present;
  if status_ret.all <> status_$ok then
    return;

  { the page table, made once }
  table := page_table;
  if table = nil then begin
    gpu_$lock(status_ret);
    if status_ret.all = status_$ok then begin
      if page_table = nil then begin
        file_$create(uid_$nil, file_uid, status_ret);
        if status_ret.all = status_$ok then begin
          table := mst_$maps(0, true, file_uid, 0, 43008, 6, 0, true,
                             map_info, status_ret);
          if status_ret.all = status_$ok then
            page_table := table;
        end;
      end;
      gpu_$unlock;
    end;
    if page_table <> nil then
      status_ret.all := status_$ok
    else if status_ret.all <> status_$ok then
      return;
  end;

  pages_wired[proc1_$current] := 0;
  page_min[proc1_$current] := 256;
  page_max[proc1_$current] := 256;
  proc2_$set_cleanup(9);
%else
  status_ret.all := status_$gpu_device_not_present;
%endif
end;
