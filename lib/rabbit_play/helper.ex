defmodule RabbitPlay.Helper do
  use AMQP

  alias RabbitPlay.BasicConsumer

  require Logger

  @exchange "agreements"

  @queue_a "queue_a"
  @queue_b "queue_b"
  @queue_c "queue_c"
  @arguments_a [{"format", "pdf"}, {"type", "report"}]
  @arguments_b [{"format", "pdf"}, {"type", "log"}]
  @arguments_c [{"format", "zip"}, {"type", "report"}]

  @rabbit_user "guest"
  @rabbit_pass "guest"
  @rabbit_host "localhost"

  @routing_key ""

  # Opens connection too
  def get_channel() do
    {:ok, conn} = Connection.open("amqp://#{@rabbit_user}:#{@rabbit_pass}@#{@rabbit_host}")
    {:ok, chan} = Channel.open(conn)

    {:ok, chan}
  end

  def basic_setup(chan) do
    # Declare exchange
    :ok = Exchange.declare(chan, @exchange, :headers, durable: true)

    # Declare queues
    [@queue_a, @queue_b, @queue_c]
    |> Enum.each(fn queue ->
      Queue.declare(chan, queue, durable: true)
    end)

    # Bind queues
    [{@queue_a, @arguments_a}, {@queue_b, @arguments_b}, {@queue_c, @arguments_c}]
    |> Enum.each(fn {queue, arguments} ->
      Queue.bind(chan, queue, @exchange, arguments: arguments)
    end)
  end

  def basic_setup(chan, queues_and_arguments) do
    # Declare exchange
    :ok = Exchange.declare(chan, @exchange, :headers, durable: true)

    # Declare queues
    queues_and_arguments
    |> Enum.each(fn {queue, _} ->
      Queue.declare(chan, queue, durable: true)
    end)

    # Bind queues
    queues_and_arguments
    |> Enum.each(fn {queue, arguments} ->
      Queue.bind(chan, queue, @exchange, arguments: arguments)
    end)
  end

  def publish_with_headers(chan, message, headers) do
    Basic.publish(
      chan,
      @exchange,
      @routing_key,
      message,
      headers: headers
    )
  end

  def delete_queues(chan, config) do
    config
    |> Enum.map(fn %{queues_config: queues_config} -> queues_config end)
    |> List.flatten()
    |> Enum.map(fn {queue, _} -> Queue.delete(chan, queue) end)
  end

  def test_publishes() do
    consumer_1_config = %{
      name: "Consumer1",
      queues_config: [
        {"queue_a", [{"format", "pdf"}, {"type", "report"}]}
      ]
    }

    consumer_2_config = %{
      name: "Consumer2",
      queues_config: [
        {"queue_b", [{"format", "zip"}, {"type", "log"}, {"x-match", "any"}]}
      ]
    }

    consumer_3_config = %{
      name: "Consumer3",
      queues_config: [
        {"queue_c", [{"format", "zip"}, {"type", "report"}, {"x-match", "all"}]}
      ]
    }

    test_config = [
      consumer_1_config,
      consumer_2_config,
      consumer_3_config
    ]

    # Get queues_config from test_config
    queues_config =
      test_config
      |> Enum.map(fn %{queues_config: queues_config} -> queues_config end)
      |> List.flatten()

    # Config connection and channel
    {:ok, chan} = get_channel()
    basic_setup(chan, queues_config)

    # Add channel to consumer config and start consumer
    test_config
    |> Enum.map(&Map.put(&1, :channel, chan))
    |> Enum.each(&BasicConsumer.start_link/1)

    # This message should reach @queue_a
    publish_with_headers(chan, "Test 1: should reach", [
      {"format", "pdf"},
      {"type", "report"}
    ])

    # This message should reach @queue_a and @queue_b
    publish_with_headers(chan, "Test 2: should not reach", [
      {"format", "pdf"}
    ])

    # This message should not reach any queue
    publish_with_headers(chan, "Test 3: should reach", [
      {"format", "zip"},
      {"type", "report"}
    ])

    {:ok, %{channel: chan, test_config: test_config}}
  end
end
