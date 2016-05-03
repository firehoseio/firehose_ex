ExUnit.start()

defmodule TestHelper do
  defmacro __using__(_opts) do
    quote do
      require TestHelper
      import TestHelper
    end
  end
end
