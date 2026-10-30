{ FILE_$MK_TEMPORARY - make an object temporary: nothing to do, ok.

  Image addresses:
    sau2  0x00E5DBB2  FILE_$MK_TEMPORARY

  - The object's UID is not read (FILE_$MK_PERMANENT's code, byte for
    byte).

  Status stored:
    status_$ok: always
}

procedure file_$mk_temporary(in file_uid: uid_$t; out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
end;
