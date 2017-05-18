defmodule JsonStoreTest do
  use ExUnit.Case
  doctest JsonStore

  defmodule TestModel do
    use Extruder
    use JsonStore.Model

    defmodel do
      field :id, :string, key: true
      field :foo, :string
      field :bar, :int
    end
  end

  describe "update" do
    test "valid change" do
      model = %TestModel{id: "a", foo: "bar"}
      change = %{bar: 2}
      TestModel.update(model, change)
    end
  end
end
