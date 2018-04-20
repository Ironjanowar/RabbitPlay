defmodule RabbitPlay.BasicConsumer do
  use GenServer
  use AMQP

  alias RabbitPlay.Helper

  require Logger

  # Client API
  def start_link(chan, name, queues_and_arguments) when is_list(queues_and_arguments) do
    GenServer.start_link(__MODULE__, {chan, name, queues_and_arguments})
  end

  # Server callbacks
  def init({chan, name, queues_and_arguments}) do
    Helper.basic_setup(chan, queues_and_arguments)

    queues_and_arguments |> Enum.each(fn {queue, _} -> Basic.consume(chan, queue) end)

    {:ok, %{chan: chan, queues: queues_and_arguments, consumer_name: name}}
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

  def handle_info(
        {:basic_deliver, payload, %{delivery_tag: tag} = extra},
        %{chan: chan, consumer_name: name} = state
      ) do
    Logger.info("EXTRA: #{inspect(extra)}")

    spawn(fn ->
      Logger.info("#{name}: #{payload}")
      Basic.ack(chan, tag)
    end)

    {:noreply, state}
  end
end
