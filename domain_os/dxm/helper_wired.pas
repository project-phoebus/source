{ DXM_$HELPER_WIRED - the wired DXM helper process.

  Image addresses:
    sau2  0x00E1721E  DXM_$HELPER_WIRED

  - Takes ml_$server_lock and runs DXM_$WIRED_Q forever; a process entry
    point OS_$INIT creates.

  Status stored: none.
}

procedure dxm_$helper_wired;
begin
  proc1_$set_lock(ml_$server_lock);
  dxm_$helper_common(dxm_$wired_q);
end;
