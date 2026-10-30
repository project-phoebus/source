{ FILE_$SET_REFCNT - set an object's reference count, deleting it at 0.

  Image addresses:
    sau2  0x00E5E3F4  FILE_$SET_REFCNT

  - The count becomes the reference count (attribute 8) through
    FILE_$SET_ATTRIBUTE (control rights 8, all options): -1 as 0, 65525
    or more (unsigned) as -11.
  - A count set to 0 deletes the object (file_$delete_int with the flags
    1), its result and status dropped.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_refcnt(in file_uid: uid_$t; refcnt: linteger;
                           out status_ret: status_$t);
var
  value: file_$attr_value_t;
  del_status: status_$t;
  result: boolean;
begin
  if refcnt = -1 then
    value.word_val := 0
  else if refcnt < 65525 then
    value.word_val := refcnt
  else
    value.word_val := -11;

  file_$set_attribute(file_uid, 8, value, 8, -1, status_ret);

  if (status_ret.all = status_$ok) and then (value.word_val = 0) then
    discard(file_$delete_int(file_uid, 1, result, del_status));
end;
