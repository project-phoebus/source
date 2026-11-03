{ ring_8025_reset - reset an adapter and wait for its bring-up
  diagnostics.

  Image addresses:
    sau8  0x03C89498  ring_8025_reset
    sau9  0x3C485098  ring_8025_reset

  - Up to three resets, each polled three times a tick apart: the
    controller is ready when its status shows initialize and neither
    test nor error, and no interrupt code.  Test and error together
    end the tries.

  Status stored:
    status_$ok: the controller is ready to be initialized
    status_$r8025_adapter_hardware_error: it did not come up
}

procedure ring_8025_reset(var regs: ring_8025_$regs_ptr_t;
                          out status: status_$t); internal;
label
  fail;
var
  sts: ring_8025_$sifsts_t;
  tries: integer;
  polls: integer;
begin
  for tries := 1 to 3 do begin
    regs^.reset := regs^.reset ! 1;
    regs^.control_3 := regs^.control_3 ! 8;
    regs^.reset := regs^.reset & 16#FE;
    for polls := 1 to 3 do begin
      ring_8025_wait(1);
      sts := regs^.sifsts;
      if (sts.int_code = 0) and then not sts.error and then sts.initialize
         and then not sts.test then begin
        status.all := status_$ok;
        return;
      end;
      if sts.test and then sts.error then
        goto fail;
    end;
  end;
fail:
  status.all := status_$r8025_adapter_hardware_error;
end;
