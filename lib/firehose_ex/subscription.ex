defmodule FirehoseEx.Subscription do
  defstruct channel: nil,         # channel name
            last_sequence: nil,
            subscriber: nil,      # subscriber pid
            monitor_ref: nil      # used by subscription manager
end
