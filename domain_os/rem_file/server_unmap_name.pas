{ server_unmap_name - map a request's name back from the network's case.

  Image addresses:
    sau2  0x00E62CEA  server_unmap_name (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment); the loop's index is the parent's tmp_index.
  - The name and its length are converted in place; UNMAP_CASE's
    truncation flag is not read.

  Status stored: none.
}

  procedure server_unmap_name(in out name: univ name_$name_t;
                              in out name_len: pinteger);
  var
    converted: name_$name_t;
    converted_len: integer;
    truncated: boolean;
  begin
    unmap_case(name, name_len, converted, 16#20, converted_len, truncated);

    name_len := converted_len;

    for tmp_index := 1 to converted_len do
      name[tmp_index] := converted[tmp_index];
  end;
