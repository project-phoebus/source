{ DXM_$HELPER_UNWIRED - the unwired DXM helper process.

  Image addresses:
    sau2  0x00E17246  DXM_$HELPER_UNWIRED

  - Takes ml_$term_lock and runs DXM_$UNWIRED_Q forever; a process entry
    point OS_$INIT creates.

  Status stored: none.
}

procedure dxm_$helper_unwired;
begin
  proc1_$set_lock(ml_$term_lock);
  dxm_$helper_common(dxm_$unwired_q);
end;
