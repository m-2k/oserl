defmodule MC do
  @behaviour :gen_mc

  @default_smpp_port 2775

  ### -----------------------------------------------------------------------------
  ### START/STOP EXPORTS
  ### -----------------------------------------------------------------------------
  def start_link(), do: start_link(true)

  def start_link(silent) do
    opts = [addr: {127, 0, 0, 1}, port: @default_smpp_port]

    :gen_mc.start_link({:local, __MODULE__}, __MODULE__, [silent], opts)
  end

  def stop() do
    fun = fn pid -> :gen_mc.unbind(__MODULE__, pid, []) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :txs))

    :timer.sleep(1_000)

    :gen_mc.call(__MODULE__, :stop)
  end

  ### -----------------------------------------------------------------------------
  ### SMPP EXPORTS
  ### -----------------------------------------------------------------------------
  def alert_notification(params) do
    fun = fn x -> :gen_mc.alert_notification(__MODULE__, x, params) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def data_sm(params) do
    fun = fn x -> :gen_mc.data_sm(__MODULE__, x, params, []) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def deliver_sm(params) do
    fun = fn x -> :gen_mc.deliver_sm(__MODULE__, x, params, []) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def outbind(addr, port, params) do
    case :gen_mc.outbind(__MODULE__, addr, [{:port, port}], params) do
      {:ok, _pid} ->
        :ok

      error ->
        error
    end
  end

  ### -----------------------------------------------------------------------------
  ### QUEUE EXPORTS
  ### -----------------------------------------------------------------------------
  def queue_data_sm(params) do
    fun = fn x -> :gen_mc.queue_data_sm(__MODULE__, x, params, []) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def queue_deliver_sm(params) do
    fun = fn x -> :gen_mc.queue_deliver_sm(__MODULE__, x, params, []) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  ### -----------------------------------------------------------------------------
  ### RPS EXPORTS
  ### -----------------------------------------------------------------------------
  def resume() do
    fun = fn x -> :gen_mc.resume(__MODULE__, x) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def pause() do
    fun = fn x -> :gen_mc.pause(__MODULE__, x) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def rps() do
    fun = fn x -> :gen_mc.rps(__MODULE__, x) end
    :lists.map(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def rps_max() do
    fun = fn x -> :gen_mc.rps_max(__MODULE__, x) end
    :lists.map(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  def rps_max(rps_max) do
    fun = fn x -> :gen_mc.rps_max(__MODULE__, x, rps_max) end
    :lists.foreach(fun, :gen_mc.call(__MODULE__, :rxs))
  end

  ### -----------------------------------------------------------------------------
  ### STATUS EXPORTS
  ### -----------------------------------------------------------------------------
  def failure(), do: :gen_mc.call(__MODULE__, :failure, :infinity)

  def reset(), do: :gen_mc.cast(__MODULE__, :reset)

  def silent(silent), do: :gen_mc.cast(__MODULE__, {:silent, silent})

  def success(), do: :gen_mc.call(__MODULE__, :success, :infinity)

  ### -----------------------------------------------------------------------------
  ### INIT/TERMINATE EXPORTS
  ### -----------------------------------------------------------------------------
  def init([silent]) do
    {
      :ok,
      %{
        silent: silent,
        msg_id: 0,
        rxs: [],
        txs: [],
        failure: 0,
        success: 0
      }
    }
  end

  def terminate(_reason, _st), do: :ok

  ### -----------------------------------------------------------------------------
  ### HANDLE MESSAGES EXPORTS
  ### -----------------------------------------------------------------------------
  def handle_call(:rxs, _from, st), do: {:reply, st.rxs, st}
  def handle_call(:txs, _from, st), do: {:reply, st.txs, st}
  def handle_call(:stop, _from, st), do: {:stop, :normal, :ok, st}
  def handle_call(:failure, _from, st), do: {:reply, st.failure, st}
  def handle_call(:success, _from, st), do: {:reply, st.success, st}

  def handle_cast(:reset, st), do: {:noreply, %{st | failure: 0, success: 0}}
  def handle_cast({:silent, silent}, st), do: {:noreply, %{st | silent: silent}}

  def handle_info(_info, st), do: {:noreply, st}

  ### -----------------------------------------------------------------------------
  ### CODE UPDATE EXPORTS
  ### -----------------------------------------------------------------------------
  def code_change(_old_vsn, st, _extra), do: {:ok, st}

  ### -----------------------------------------------------------------------------
  ### MC EXPORTS
  ### -----------------------------------------------------------------------------
  def handle_accept(_pid, addr, _from, st) do
    ip = format_ip(addr)

    case :rand.uniform(100) do
      n when n < 25 ->
        :logger.info("Connection from #{inspect(ip)} refused")
        {:reply, {:error, :refused}, st}

      _n ->
        :logger.info("Accepted connection from #{inspect(ip)}")
        {:reply, {:ok, [{:rps, 100}]}, st}
    end
  end

  def handle_bind_receiver(pid, pdu, _from, st) do
    case bind_resp(pid, pdu, st) do
      {:ok, _params} = reply ->
        {:reply, reply, %{st | rxs: [pid | st.rxs]}}

      error ->
        {:reply, error, st}
    end
  end

  def handle_bind_transceiver(pid, pdu, _from, st) do
    case bind_resp(pid, pdu, st) do
      {:ok, _params} = reply ->
        {:reply, reply, %{st | rxs: [pid | st.rxs], txs: [pid | st.txs]}}

      error ->
        {:reply, error, st}
    end
  end

  def handle_bind_transmitter(pid, pdu, _from, st), do: {:reply, bind_resp(pid, pdu, st), st}

  def handle_broadcast_sm(_pid, _pdu, _from, st) do
    params = [{:message_id, :erlang.integer_to_list(st.msg_id)}]
    {:reply, {:ok, params}, %{st | msg_id: st.msg_id + 1}}
  end

  def handle_cancel_broadcast_sm(_pid, _pdu, _from, st), do: {:reply, {:ok, []}, st}

  def handle_cancel_sm(_pid, _pdu, _from, st), do: {:reply, {:ok, []}, st}

  def handle_closed(pid, reason, st) do
    :logger.info("Session #{inspect(pid)} closed with reason #{inspect(reason)}")
    {:noreply, %{st | rxs: :lists.delete(pid, st.rxs), txs: :lists.delete(pid, st.txs)}}
  end

  def handle_data_sm(_pid, _pdu, _from, st) do
    if rem(st.msg_id, 10) == 0 do
      {:reply, {:error, 85}, %{st | msg_id: st.msg_id + 1}}
    else
      params = [{:message_id, :erlang.integer_to_list(st.msg_id)}]
      {:reply, {:ok, params}, %{st | msg_id: st.msg_id + 1}}
    end
  end

  def handle_query_broadcast_sm(_pid, pdu, _from, st) do
    bcast_area = :smpp_base.broadcast_area(0, 'area_name')

    params = [
      {:message_id, :smpp_operation.get_value(:message_id, pdu)},
      {:message_state, 2},
      {:broadcast_area_identifier, [bcast_area]},
      {:broadcast_area_success, [100]}
    ]

    {:reply, {:ok, params}, st}
  end

  def handle_query_sm(_pid, pdu, _from, st) do
    params = [
      {:message_id, :smpp_operation.get_value(:message_id, pdu)},
      {:final_date, '090423195134104+'},
      {:message_state, 2},
      {:error_code, 0}
    ]

    {:reply, {:ok, params}, st}
  end

  def handle_replace_sm(_pid, _pdu, _from, st), do: {:reply, {:ok, []}, st}

  def handle_req(_pid, _req, _args, _ref, st), do: {:noreply, st}

  def handle_resp(_pid, _resp, _ref, st), do: {:noreply, st}

  def handle_submit_multi(pid, pdu, _from, st) do
    :logger.info("Session: #{inspect(pid)} Received: #{inspect(pdu)}")

    case random_submit_status() do
      0 ->
        msg_id = :erlang.integer_to_list(st.msg_id)
        :logger.info("Message ID: #{inspect(msg_id)}")
        params = [{:message_id, msg_id}, {:unsuccess_sme, []}]
        {:reply, {:ok, params}, %{st | msg_id: st.msg_id + 1, success: st.success + 1}}

      status ->
        reason = :smpp_error.format(status)
        :logger.info("Error: #{inspect(reason)}")
        {:reply, {:error, status}, %{st | failure: st.failure + 1}}
    end
  end

  def handle_submit_sm(pid, pdu, _from, st) do
    :logger.info("Session: #{inspect(pid)} Received: #{inspect(pdu)}")

    case random_submit_status() do
      0 ->
        msg_id = :erlang.integer_to_list(st.msg_id)
        :logger.info("Message ID: #{inspect(msg_id)}")
        params = [{:message_id, msg_id}]
        {:reply, {:ok, params}, %{st | msg_id: st.msg_id + 1, success: st.success + 1}}

      status ->
        reason = :smpp_error.format(status)
        :logger.info("Error: #{inspect(reason)}")
        {:reply, {:error, status}, %{st | failure: st.failure + 1}}
    end
  end

  def handle_unbind(pid, _pdu, _from, st) do
    {:reply, :ok, %{st | rxs: :lists.delete(pid, st.rxs), txs: :lists.delete(pid, st.txs)}}
  end

  ### -----------------------------------------------------------------------------
  ### FORMAT FUNCTIONS
  ### -----------------------------------------------------------------------------
  def format_ip({a, b, c, d}), do: :io_lib.format("~p.~p.~p.~p", [a, b, c, d])

  ### -----------------------------------------------------------------------------
  ### INTERNAL FUNCTIONS
  ### -----------------------------------------------------------------------------
  def bind_resp(pid, pdu, _st) do
    system_id = :smpp_operation.get_value(:system_id, pdu)
    password = :smpp_operation.get_value(:password, pdu)
    :logger.info("Bind request from: #{inspect(system_id)}/#{inspect(password)}")

    case random_bind_status() do
      0 ->
        :logger.info("System Id: test_mc")
        params = [{:system_id, :erlang.binary_to_list("test_mc")}, {:sc_interface_version, 80}]
        {:ok, params}

      status ->
        reason = :smpp_error.format(status)
        :logger.info("Rejected: #{inspect(reason)}")
        :gen_mc.close(__MODULE__, pid)
        {:error, status}
    end
  end

  def random_bind_status() do
    case :rand.uniform(1000) do
      n when n <= 25 -> 13
      _n -> 0
    end
  end

  def random_submit_status() do
    case :rand.uniform(1000) do
      n when n <= 10 -> 8
      n when n <= 20 -> 20
      n when n <= 30 -> 69
      n when n <= 40 -> 88
      _n -> 0
    end
  end
end
