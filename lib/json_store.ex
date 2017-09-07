defmodule JsonStore do
  require Record
  Record.defrecord :cql_query_batch, Record.extract(:cql_query_batch, from_lib: "cqerl/include/cqerl.hrl")

  def find(module, params) do
    table = table_name(module)
    clauses = Enum.reduce params, [], fn({key, _value}, clauses) ->
      clauses ++ ["#{key}=:#{key}"]
    end
    clauses_sql = Enum.join(clauses, " AND ")
    sql = "SELECT JSON * FROM #{table} where #{clauses_sql}"

    case query_and_parse(module, sql, params) do
      {:ok, [record]} -> {:ok, record}
        {:ok, []} -> :error
      {:ok, rep} ->
          raise :multiple_records_found
      other -> other
    end
  end

  def save(module, record, opt \\ %{}) do
    table = table_name(module)
    {:ok, json} = to_json(module, record)

    ttl_clause_sql = ttl_clause(opt)
    sql = "INSERT INTO #{table} JSON :json #{ttl_clause_sql}"
    params = %{json: json}

    case send_query sql, params do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def update(module, record, changes, opt \\ %{}) do
    table = table_name(module)

    # Where part
    params = params_from_keys(module, record)
    where_clauses = Enum.map params, fn({id, value}) ->
      " #{id} = :#{id} "
    end
    where_clauses_sql = Enum.join(where_clauses, " AND ")


    # Set part
    {set_clauses, params} = Enum.reduce changes, {[], params} , fn({key, _value}, {clauses, params}) ->
      clauses = clauses ++ ["#{key}=:#{key}"]
      value = Map.get changes, key
      params = Map.put params, key, value
      {clauses, params}
    end

    set_clauses_sql = Enum.join(set_clauses, ",")

    ttl_clause_sql = ttl_clause(opt)
    sql = "UPDATE #{table} #{ttl_clause_sql} SET #{set_clauses_sql} where #{where_clauses_sql}"

  end

  defp ttl_clause(opt) do
    case opt[:ttl] do
      nil -> ""
      ttl -> "USING TTL #{ttl}"
    end
  end

  def all(module) do
    table = table_name(module)
    sql = "SELECT JSON * FROM #{table}"
    query_and_parse(module, sql)
  end

  def select(module, fields, clause, params \\ %{}) do
    fields_sql = Enum.join(fields, ", ")
    table = table_name(module)
    sql = "SELECT JSON #{fields_sql} FROM #{table} where #{clause}"
    query_and_parse(module, sql, params)
  end


  def where(module, clause, params) do
    table = table_name(module)
    sql = "SELECT JSON * FROM #{table} where #{clause}"
    query_and_parse(module, sql, params)
  end

  def where(module, params) when is_map(params) do
    table = table_name(module)
    clauses = Enum.reduce params, [], fn({key, _value}, clauses) ->
      clauses ++ ["#{key}=:#{key}"]
    end
    clauses_sql = Enum.join(clauses, " AND ")
    sql = "SELECT JSON * FROM #{table} where #{clauses_sql}"
    query_and_parse(module, sql, params)
  end

  defp query_and_parse(module, sql, params \\ %{}) do
    case send_query sql, params do
      {:ok, res} ->
        records = Enum.map res, fn(["[json]": json]) ->
          Poison.decode!(json) |> module.extrude!
        end
      {:ok, records}
      other -> other
    end
  end


  def destroy(module, record) do
    table = table_name(module)

    params = params_from_keys(module, record)
    clauses = Enum.map params, fn({id, value}) ->
      " #{id} = :#{id} "
    end
    clauses_sql = Enum.join(clauses, " AND ")

    sql = "DELETE FROM #{table} where #{clauses_sql}"
    case send_query sql, params do
      {:ok, _res} -> :ok
      error -> error
    end
  end


  def send_query(statement, values) do
    query = %CQEx.Query{
      statement: statement,
      values:  values
    }
    CQEx.Query.call(CQEx.Client.new!, query)
  end


  def send_queries(queries) do
    client = CQEx.Client.get Domoio.Cassandra.client
    cqerl_queries = Enum.map(queries, fn(q) -> CQEx.Query.convert q end)
    :cqerl.run_query(client, cql_query_batch(queries: cqerl_queries))
  end


  def to_map(module, record) do
    Enum.reduce module.fields_list, %{}, fn({name, type, _opt}, data) ->
      value = Map.get record, name
      cond do
        value && (is_list(value) || is_map(value)) ->
          {:ok, value} = Poison.encode value
          Map.put data, name, value
        value ->
          Map.put data, name, value
        true -> data
      end
    end
  end

  def to_json(module, record), do: to_map(module, record) |> Poison.encode

  defp table_name(module) do
    Atom.to_string(module) |> String.split(".") |> List.last |> Inflex.pluralize |> Inflex.underscore
  end

  defp params_from_keys(module, record, map \\ %{}) do
    Enum.reduce module.fields_list, map, fn({id, _type, opts}, keys) ->
      case opts do
        [key: true] ->
          value = Map.get record, id
          Map.put keys, id, value
        _ -> keys
      end
    end
  end
end
