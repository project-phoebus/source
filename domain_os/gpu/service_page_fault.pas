{ gpu_$service_page_fault - answer a page fault of the graphics
  processor.

  Image addresses:
    sau5  0x00E73B08  gpu_$service_page_fault (module-local)
    sau6  0x7807AA18  gpu_$service_page_fault (module-local)

  - Reads the faulting address from the processor (its registers 16#8006
    and 16#8007), wires the page, which gives the processor the mapping,
    and tells the processor to go on.
  - The first failure stops it; gpu_stat is the last status word read.

  Status stored:
    status_$ok: the fault was answered
    gpu_$pio_write's, gpu_$wait_pio's or gpu_$wire_page's status: a step
      failed
}

procedure gpu_$service_page_fault(out gpu_stat: pinteger;
                                  out status: status_$t);
  internal;
type
  fault_va_t = record
    high: pinteger;                       { 0x00 }
    low: pinteger;                        { 0x02 }
  end;
var
  cmd: gpu_cmd_t;
  fault_va: fault_va_t;
  done: integer;
begin
  cmd.op := 16#41C2;
  cmd.len := 2;
  cmd.arg1 := 16#8006;
  gpu_$pio_write(cmd, 4, done, gpu_stat, status);
  if status.all <> status_$ok then
    return;
  gpu_$wait_pio(gpu_stat, status);
  if status.all <> status_$ok then
    return;
  fault_va.high := gpu.data;

  cmd.arg1 := 16#8007;
  gpu_$pio_write(cmd, 4, done, gpu_stat, status);
  if status.all <> status_$ok then
    return;
  gpu_$wait_pio(gpu_stat, status);
  if status.all <> status_$ok then
    return;
  fault_va.low := gpu.data;

  gpu_$wire_page(integer32(fault_va), status);
  if status.all <> status_$ok then
    return;

  cmd.op := 16#41E5;
  cmd.len := 0;
  gpu_$pio_write(cmd, 2, done, gpu_stat, status);
end;
