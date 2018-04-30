defmodule RabbitPlay.BasicConsumer do
  use GenServer
  use AMQP

  alias RabbitPlay.Helper

  require Logger

  # Client API
  def start_link(config) when is_map(config) do
    GenServer.start_link(__MODULE__, config)
  end

  # Server callbacks
  def init(%{channel: chan, name: name, queues_config: queues_config}) do
    Helper.basic_setup(chan, queues_config)

    queues_config |> Enum.each(fn {queue, _} -> Basic.consume(chan, queue) end)

    Logger.info("Consumer #{name} started")

    {:ok, %{chan: chan, queues: queues_config, consumer_name: name}}
  end

  def init(%{channel: chan, name: name, queues: queues}) do
    queues
    |> Enum.each(fn queue ->
      Queue.declare(chan, queue, durable: true)
      Basic.consume(chan, queue)
    end)

    Logger.info("Consumer #{name} started")

    {:ok, %{chan: chan, queues: queues, consumer_name: name}}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, _}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, "stop", _}, state) do
    {:stop, "STOP message received from RabbitMQ", state}
  end

  def handle_info(
        {:basic_deliver, payload, %{delivery_tag: tag}},
        %{chan: chan, consumer_name: name} = state
      ) do
    spawn(fn ->
      Logger.info("#{name}: #{payload}")
      Basic.ack(chan, tag)
    end)

    {:noreply, state}
  end
end
