{ PACCT_$ON - whether accounting is on.

  Image addresses:
    sau2  0x00E5A9A4  PACCT_$ON

  - True when the accounting file's UID is not UID_$NIL.

  Status stored: none.
}

function pacct_$on: boolean;
begin
  pacct_$on := pacct_owner <> uid_$nil;
end;
