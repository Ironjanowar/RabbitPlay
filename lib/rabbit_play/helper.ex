defmodule RabbitPlay.Helper do
  use AMQP

  alias RabbitPlay.BasicConsumer

  require Logger

  @exchange "argeements"

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

  def test_publishes() do
    test_config = [
      {"queue_a", [{"format", "pdf"}, {"type", "report"}]},
      {"queue_b", [{"format", "pdf"}, {"type", "log"}]},
      {"queue_c", [{"format", "zip"}, {"type", "report"}]}
    ]

    # Config connection and channel
    {:ok, chan} = get_channel()
    basic_setup(chan, test_config)

    # Start consumer
    BasicConsumer.start_link(chan, test_config)

    # This message should reach @queue_a
    publish_with_headers(chan, "Test 1: should reach", [
      {"format", "pdf"},
      {"type", "report"},
      {"x-match", "all"}
    ])

    # This message should reach @queue_a and @queue_b
    publish_with_headers(chan, "Test 2: should reach", [{"format", "pdf"}, {"x-match", "any"}])

    # This message should not reach any queue
    publish_with_headers(chan, "Test 3: should not reach", [
      {"format", "zip"},
      {"type", "log"},
      {"x-match", "all"}
    ])
  end
end
