defmodule RabbitPlay.Helper do
  use AMQP

  require Logger

  @exchange "test_exchange"
  @test_queue "test_queue"
  @user_queue "user_queue"
  @rabbit_user "guest"
  @rabbit_pass "guest"
  @rabbit_host "localhost"
  @test_arguments [{"test", "test"}]
  @user_arguments [{"user-id", 1}]
  @routing_key ""

  def get_connection() do
    {:ok, conn} = Connection.open("amqp://#{@rabbit_user}:#{@rabbit_pass}@#{@rabbit_host}")
    {:ok, chan} = Channel.open(conn)

    {:ok, chan}
  end

  def basic_setup(chan) do
    # Declare exchange
    :ok = Exchange.declare(chan, @exchange, :headers, durable: true)

    # Declare queues
    {:ok, _} = Queue.declare(chan, @test_queue, durable: true)
    {:ok, _} = Queue.declare(chan, @user_queue, durable: true)

    # Bind queues
    Queue.bind(chan, @test_queue, @exchange, arguments: @test_arguments)
    Queue.bind(chan, @user_queue, @exchange, arguments: @user_arguments)
  end

  # Sends message to "@test_queue" by default
  def send_with_headers(chan, message, headers \\ [{"test", "test"}]) do
    Basic.publish(
      chan,
      @exchange,
      @routing_key,
      message,
      headers: headers
    )
  end
end
