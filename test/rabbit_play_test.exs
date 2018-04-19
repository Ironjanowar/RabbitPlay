defmodule RabbitPlayTest do
  use ExUnit.Case
  doctest RabbitPlay

  test "greets the world" do
    assert RabbitPlay.hello() == :world
  end
end
