defmodule GenMcTest do
  use ExUnit.Case

  @deliver_sm [
    {'0123456789', 'hello world'},
    {'0234567891', 'bye bye'},
    {'0345678912', 'foo bar baz'}
  ]

  test "receiver" do
    {:ok, _mc} = MC.start_link(false)
    {:ok, _esme} = ESME.start_link(:rx, false)

    wait_bound()

    alert_notification()
    deliver_loop(1, 100)

    wait(180)

    MC.stop()

    :timer.sleep(1_000)

    ESME.stop()
  end

  test "queue_receiver" do
    {:ok, _mc} = MC.start_link(false)
    {:ok, _esme} = ESME.start_link(:trx, false)

    wait_bound()

    MC.resume()

    queue_deliver_loop(1, 100)

    wait(180)

    MC.stop()

    :timer.sleep(1_000)

    ESME.stop()
  end

  defp alert_notification() do
    params = [
      {:source_addr_ton, 2},
      {:source_addr_npi, 1},
      {:source_addr, '0123456789'},
      {:esme_addr_ton, 2},
      {:esme_addr_npi, 1},
      {:esme_addr, '*'},
      {:ms_availability_status, 0}
    ]

    MC.alert_notification(params)
  end

  defp deliver_loop(sleep, times), do: deliver_loop(hd(@deliver_sm), sleep, times)

  defp deliver_loop({x, y} = msg, sleep, times) when times > 0 do
    params = [
      {:source_addr, x},
      {:source_addr_ton, 2},
      {:source_addr_npi, 1},
      {:dest_addr_ton, 2},
      {:dest_addr_npi, 1},
      {:destination_addr, '9999'},
      {:esm_class, 0},
      {:protocol_id, 0},
      {:priority_flag, 0}
    ]

    MC.deliver_sm([{:short_message, y} | params])
    MC.data_sm([{:message_payload, y} | params])

    if sleep > 0, do: :timer.sleep(sleep)

    deliver_loop(msg, sleep, times - 1)
  end

  defp deliver_loop(_msg, _sleep, _times), do: :ok

  defp queue_deliver_loop(sleep, times), do: queue_deliver_loop(hd(@deliver_sm), sleep, times)

  defp queue_deliver_loop({x, y} = msg, sleep, times) when times > 0 do
    params = [
      {:source_addr, x},
      {:source_addr_ton, 2},
      {:source_addr_npi, 1},
      {:dest_addr_ton, 2},
      {:dest_addr_npi, 1},
      {:destination_addr, '9999'},
      {:esm_class, 0},
      {:protocol_id, 0},
      {:priority_flag, 0}
    ]

    MC.queue_deliver_sm([{:short_message, y} | params])
    MC.queue_data_sm([{:message_payload, y} | params])

    if sleep > 0, do: :timer.sleep(sleep)

    queue_deliver_loop(msg, sleep, times - 1)
  end

  defp queue_deliver_loop(_msg, _sleep, _times), do: :ok

  defp wait(count) do
    case ESME.recv() do
      c when c >= count ->
        :ok

      _other ->
        :timer.sleep(200)
        wait(count)
    end
  end

  defp wait_bound() do
    if ESME.bound() do
      :ok
    else
      :timer.sleep(3_000)
      wait_bound()
    end
  end
end
