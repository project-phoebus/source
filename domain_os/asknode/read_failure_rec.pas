{ ASKNODE_$READ_FAILURE_REC - copy out the network failure record.

  Image addresses:
    sau2  0x00E658D0  ASKNODE_$READ_FAILURE_REC

  - With NETWORK_$ACTIVITY_FLAG set the record's flag is cleared first,
    as ASKNODE_$INTERNET_INFO's request 16#2F does.

  Status stored: none.
}

procedure asknode_$read_failure_rec(out failure_rec: network_$failure_rec_t);
begin
  if network_$activity_flag then
    network_$failure_rec.flag := false;
  failure_rec := network_$failure_rec;
end;
