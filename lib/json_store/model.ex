defmodule JsonStore.Model do
  defmacro __using__(_opts) do
    quote do
      import Extruder
      @__extruder__ %{validations: [], fields: []}
      def find(params), do: JsonStore.find(__MODULE__, params)
      def save(record, opt \\ %{}), do: JsonStore.save(__MODULE__, record, opt)
      def destroy(record), do: JsonStore.destroy(__MODULE__, record)
      def where(params), do: JsonStore.where(__MODULE__, params)
      def where(clause, params), do: JsonStore.where(__MODULE__, clause, params)
      def select(fields, clause, params), do: JsonStore.select(__MODULE__, fields, clause, params)
      def update(record, changes, opt \\ %{}), do: JsonStore.update(__MODULE__, record, changes, opt)
    end
  end
end
