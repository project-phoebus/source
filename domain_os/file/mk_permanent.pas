{ FILE_$MK_PERMANENT - make an object permanent: nothing to do, ok.

  Image addresses:
    sau2  0x00E5DBA4  FILE_$MK_PERMANENT

  - The object's UID is not read.

  Status stored:
    status_$ok: always
}

procedure file_$mk_permanent(in file_uid: uid_$t; out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
end;
