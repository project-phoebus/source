{ DXM_$ADD_SIGNAL_CALLBACK - deliver a signal queued by DXM_$ADD_SIGNAL.

  Image addresses:
    sau2  0x00E72184  DXM_$ADD_SIGNAL_CALLBACK

  - The record's routine, PROC2_$SIGNAL_OS (0) or
    PROC2_$SIGNAL_PGROUP_OS (1), is called with the indexed process's
    UID, the signal and its parameter; its status is not looked at.
  - Neither index is checked.
  - Its static, 8 bytes in DATA$, holds the two routines' addresses as
    univ_ptr (their headings differ).

  Status stored: none.
}

{ TODO(pascal) calling through a type transfer's result is not a known form

  Calling through its result, `type(x)^(...)', is not a known form (the
  known sites call through a variable, field or element of a routine
  pointer type), and whether the language allows it is not settled: type
  transfers are functions (ref 4-197, "Type transfer functions are
  functions"), "you cannot de-reference the return value of a function
  call" (p. 4-145), and of a univ_ptr "You must use a variable of an
  explicit pointer type for the dereference" (3.13.2, p. 3-50); none of
  the 199 Pascal files of Apollo's SR10.2 and SR10.4 install trees
  dereferences a parenthesized expression.  `dpc --check-only' accepts
  it.  The other reading that fits the same instructions calls through
  an element: a table of two-variant records, each initialized through a
  univ_ptr variant and called through a dxm_$signal_routine_t variant
  (ref 3.10.4).  A routine pointer local assigned before the call does
  not fit: the image loads the pointer after the pushes, and the frame
  has no slot for it. }

[section(procedure$, data$)]
procedure dxm_$add_signal_callback(in data: dxm_$signal_data_ptr_t);
var
  { DATA$ +0x0 }
  dxm_$signal_routines: static array[0..1] of univ_ptr := [
    addr(proc2_$signal_os),               { 0 }
    addr(proc2_$signal_pgroup_os)];       { 1 }
  status: status_$t;
  rec: dxm_$signal_data_ptr_t;
begin
  rec := data;
  dxm_$signal_routine_t(dxm_$signal_routines[rec^.routine])^(
    proc2_$uid[rec^.proc_index], rec^.signal, rec^.param,
    status);
end;
