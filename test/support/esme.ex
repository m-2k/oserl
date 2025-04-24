defmodule ESME do
  @behaviour :gen_esme

  @bind_params [
    {:system_id, :erlang.binary_to_list("oserl")},
    {:password, :erlang.binary_to_list("oserl")},
    {:system_type, :erlang.binary_to_list("oserl")}
  ]
  @port 2775
  @addr {127, 0, 0, 1}
  @port_listen 9999

  ### -----------------------------------------------------------------------------
  ### START/STOP EXPORTS
  ### -------------------- ---------------------------------------------------------
  def start_link(mode), do: start_link(mode, true)

  def start_link(mode, silent) do
    :gen_esme.start_link({:local, __MODULE__}, __MODULE__, [mode, silent], [{:rps, 100}])
  end

  def stop(), do: :gen_esme.call(__MODULE__, :stop)

  ### -----------------------------------------------------------------------------
  ### SEND EXPORTS
  ### -----------------------------------------------------------------------------
  def send(src, dest, msg, opts) do
    params = params(src, dest)
    priority = :proplists.get_value(:priority, opts, 10)
    submit(msg, params, [], priority)
  end

  ### -----------------------------------------------------------------------------
  ### RPS EXPORTS
  ### -----------------------------------------------------------------------------
  def pause(), do: :gen_esme.pause(__MODULE__)

  def resume(), do: :gen_esme.resume(__MODULE__)

  def rps_avg(), do: :gen_esme.rps_avg(__MODULE__)

  def rps(), do: :gen_esme.rps(__MODULE__)

  def rps_max(), do: :gen_esme.rps_max(__MODULE__)

  def rps_max(rps), do: :gen_esme.rps_max(__MODULE__, rps)

  ### -----------------------------------------------------------------------------
  ### STATUS EXPORTS
  ### -----------------------------------------------------------------------------
  def bound(), do: :gen_esme.call(__MODULE__, :bound, :infinity)

  def failure(), do: :gen_esme.call(__MODULE__, :failure, :infinity)

  def recv(), do: :gen_esme.call(__MODULE__, :recv, :infinity)

  def reset(), do: :gen_esme.cast(__MODULE__, :reset)

  def silent(silent), do: :gen_esme.cast(__MODULE__, {:silent, silent})

  def success(), do: :gen_esme.call(__MODULE__, :success, :infinity)

  def show_warnings() do
    pid = :erlang.whereis(__MODULE__)
    spawn_link(fn -> show_warnings_loop(pid) end)
  end

  def show_warnings_loop(pid) do
    ref = :erlang.monitor(:process, pid)
    show_warnings_loop(pid, ref)
  end

  def show_warnings_loop(pid, ref) do
    receive do
      {'DOWN', _ref, :process, _pid, info} ->
        :logger.info("sample_esme exited: #{info}")

      _other ->
        show_warnings_loop(pid, ref)
    after
      200 ->
        case :erlang.process_info(pid, :message_queue_len) do
          {:message_queue_len, len} when len > 100 ->
            :logger.info("WARNING: #{len} messages in the inbox")

          _other ->
            :ok
        end

        show_warnings_loop(pid, ref)
    end
  end

  ### -----------------------------------------------------------------------------
  ### SMPP EXPORTS
  ### -----------------------------------------------------------------------------
  def broadcast_sm(params), do: :gen_esme.broadcast_sm(__MODULE__, params, [])

  def cancel_broadcast_sm(params), do: :gen_esme.cancel_broadcast_sm(__MODULE__, params, [])

  def cancel_sm(params), do: :gen_esme.cancel_sm(__MODULE__, params, [])

  def data_sm(params), do: :gen_esme.data_sm(__MODULE__, params, [])

  def query_broadcast_sm(params), do: :gen_esme.query_broadcast_sm(__MODULE__, params, [])

  def query_sm(params), do: :gen_esme.query_sm(__MODULE__, params, [])

  def replace_sm(params), do: :gen_esme.replace_sm(__MODULE__, params, [])

  def submit_multi(params) do
    case :proplists.get_value(:short_message, params) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.submit_multi(__MODULE__, x, []) end
        :lists.foreach(fun, :smpp_sm.split(params, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.submit_multi(__MODULE__, params, [])
    end
  end

  def submit_sm(params) do
    case :proplists.get_value(:short_message, params) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.submit_sm(__MODULE__, x, []) end
        :lists.foreach(fun, :smpp_sm.split(params, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.submit_sm(__MODULE__, params, [])
    end
  end

  def submit_sm(_params, 0), do: :ok

  def submit_sm(params, n) do
    submit_sm(params)
    submit_sm(params, n - 1)
  end

  ### -----------------------------------------------------------------------------
  ### QUEUE EXPORTS
  ### -----------------------------------------------------------------------------
  def queue_broadcast_sm(params), do: :gen_esme.queue_broadcast_sm(__MODULE__, params, [])

  def queue_broadcast_sm(params, priority),
    do: :gen_esme.queue_broadcast_sm(__MODULE__, params, [], priority)

  def queue_cancel_broadcast_sm(params),
    do: :gen_esme.queue_cancel_broadcast_sm(__MODULE__, params, [])

  def queue_cancel_broadcast_sm(params, priority),
    do: :gen_esme.queue_cancel_broadcast_sm(__MODULE__, params, [], priority)

  def queue_cancel_sm(params), do: :gen_esme.queue_cancel_sm(__MODULE__, params, [])

  def queue_cancel_sm(params, priority),
    do: :gen_esme.queue_cancel_sm(__MODULE__, params, [], priority)

  def queue_data_sm(params), do: :gen_esme.queue_data_sm(__MODULE__, params, [])

  def queue_data_sm(params, priority),
    do: :gen_esme.queue_data_sm(__MODULE__, params, [], priority)

  def queue_len(), do: :gen_esme.queue_len(__MODULE__)

  def queue_out(), do: :gen_esme.queue_out(__MODULE__)
  def queue_out(num), do: :gen_esme.queue_out(__MODULE__, num)

  def queue_query_broadcast_sm(params),
    do: :gen_esme.queue_query_broadcast_sm(__MODULE__, params, [])

  def queue_query_broadcast_sm(params, priority),
    do: :gen_esme.queue_query_broadcast_sm(__MODULE__, params, [], priority)

  def queue_query_sm(params), do: :gen_esme.queue_query_sm(__MODULE__, params, [])

  def queue_query_sm(params, priority),
    do: :gen_esme.queue_query_sm(__MODULE__, params, [], priority)

  def queue_replace_sm(params), do: :gen_esme.queue_replace_sm(__MODULE__, params, [])

  def queue_replace_sm(params, priority),
    do: :gen_esme.queue_replace_sm(__MODULE__, params, [], priority)

  def queue_submit_multi(params) do
    case :proplists.get_value(:short_message, params) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.queue_submit_multi(__MODULE__, x, []) end
        :lists.foreach(fun, :smpp_sm.split(params, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.queue_submit_multi(__MODULE__, params, [])
    end
  end

  def queue_submit_multi(params, priority) do
    case :proplists.get_value(:short_message, params) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.queue_submit_multi(__MODULE__, x, [], priority) end
        :lists.foreach(fun, :smpp_sm.split(params, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.queue_submit_multi(__MODULE__, params, [], priority)
    end
  end

  def queue_submit_sm(priority) do
    case :proplists.get_value(:short_message, priority) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.queue_submit_sm(__MODULE__, x, []) end
        :lists.foreach(fun, :smpp_sm.split(priority, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.queue_submit_sm(__MODULE__, priority, [])
    end
  end

  def queue_submit_sm(params, priority) do
    case :proplists.get_value(:short_message, params) do
      sm when is_list(sm) and length(sm) > 160 ->
        ref_num = :smpp_ref_num.next(__MODULE__)
        fun = fn x -> :gen_esme.queue_submit_sm(__MODULE__, x, [], priority) end
        :lists.foreach(fun, :smpp_sm.split(params, ref_num, :udh))

      _do_not_fragment ->
        :gen_esme.queue_submit_sm(__MODULE__, params, [], priority)
    end
  end

  ### -----------------------------------------------------------------------------
  ### LOG EXPORTS
  ### -----------------------------------------------------------------------------
  def add_log_handler(handler), do: :gen_esme.add_log_handler(__MODULE__, handler, [])

  def delete_log_handler(handler), do: :gen_esme.delete_log_handler(__MODULE__, handler, [])

  def swap_log_handler(handler1, handler2) do
    :gen_esme.swap_log_handler(__MODULE__, {handler1, []}, {handler2, []})
  end

  ### -----------------------------------------------------------------------------
  ### INIT/TERMINATE EXPORTS
  ### -----------------------------------------------------------------------------
  def init([mode, silent]) do
    spawn_link(fn -> connect(mode, silent) end)

    {
      :ok,
      %{
        mode: mode,
        silent: silent,
        bound: false,
        bind_req: nil,
        reqs: [],
        msg_id: 1,
        failure: 0,
        recv: 0,
        success: 0
      }
    }
  end

  def terminate(_Reason, _St), do: :ok

  ### -----------------------------------------------------------------------------
  ### HANDLE MESSAGES EXPORTS
  ### -----------------------------------------------------------------------------
  def handle_call(:stop, _from, st) do
    self = self()
    spawn(fn -> :gen_esme.unbind(self, []) end)
    {:stop, :normal, :ok, st}
  end

  def handle_call(:bound, _from, st), do: {:reply, st.bound, st}
  def handle_call(:failure, _from, st), do: {:reply, st.failure, st}
  def handle_call(:recv, _from, st), do: {:reply, st.recv, st}
  def handle_call(:success, _from, st), do: {:reply, st.success, st}

  def handle_cast(:reset, st), do: {:noreply, %{st | failure: 0, success: 0}}
  def handle_cast({:silent, silent}, st), do: {:noreply, %{st | silent: silent}}

  def handle_info(_info, st), do: {:noreply, st}

  ### -----------------------------------------------------------------------------
  ### CODE UPDATE EXPORTS
  ### -----------------------------------------------------------------------------
  def code_change(_old_vsn, st, _extra), do: {:ok, st}

  ### -----------------------------------------------------------------------------
  ### HANDLE ESME EXPORTS
  ### -----------------------------------------------------------------------------
  def handle_accept(addr, from, st), do: :erlang.error(:function_clause, [addr, from, st])

  def handle_alert_notification(pdu, st) do
    :logger.info("Alert notification: #{inspect(pdu)}")
    {:noreply, st}
  end

  def handle_closed(reason, st) do
    :logger.info("Session closed due to reason: #{inspect(reason)}")

    connect = fn ->
      :timer.sleep(5000)
      connect(st.mode, st.silent)
    end

    spawn_link(connect)
    {:noreply, %{st | bound: false}}
  end

  def handle_data_sm(pdu, _from, st) do
    if rem(st.msg_id, 10) == 0 do
      :logger.info("Data SM: #{inspect(pdu)}")
      {:reply, {:error, 85}, %{st | msg_id: st.msg_id + 1}}
    else
      :logger.info("Data SM: #{inspect(pdu)}")
      reply = {:ok, [{:message_id, :erlang.integer_to_list(st.msg_id)}]}
      {:reply, reply, %{st | msg_id: st.msg_id + 1, recv: st.recv + 1}}
    end
  end

  def handle_deliver_sm(pdu, _from, st) do
    if rem(st.msg_id, 10) == 0 do
      :logger.info("Deliver SM: #{inspect(pdu)}")
      {:reply, {:error, 88}, %{st | msg_id: st.msg_id + 1}}
    else
      :logger.info("Deliver SM: #{inspect(pdu)}")
      reply = {:ok, [{:message_id, :erlang.integer_to_list(st.msg_id)}]}
      {:reply, reply, %{st | msg_id: st.msg_id + 1, recv: st.recv + 1}}
    end
  end

  def handle_outbind(pdu, st), do: :erlang.error(:function_clause, [pdu, st])

  def handle_req({:bind_transmitter, _params}, _args, ref, st),
    do: {:noreply, %{st | bind_req: ref}}

  def handle_req({:bind_receiver, _params}, _args, ref, st), do: {:noreply, %{st | bind_req: ref}}

  def handle_req({:bind_transceiver, _params}, _args, ref, st),
    do: {:noreply, %{st | bind_req: ref}}

  def handle_req(req, args, ref, st), do: {:noreply, %{st | reqs: [{req, args, ref} | st.reqs]}}

  def handle_resp({:ok, pdu_resp}, ref, %{bind_req: ref} = st) do
    system_id = :smpp_operation.get_value(:system_id, pdu_resp)
    :logger.info("Bound to #{inspect(system_id)}")
    retry = fn {{_, params}, args, _} -> submit(params, args, 0) end
    :lists.foreach(retry, st.reqs)
    :gen_esme.resume(__MODULE__)

    {:noreply, %{st | bound: true, reqs: []}}
  end

  def handle_resp({:error, {:command_status, status}}, ref, %{bind_req: ref} = st) do
    reason = :smpp_error.format(status)
    :logger.info("Bind error: #{inspect(reason)}")
    :gen_esme.close(__MODULE__)

    {:noreply, st}
  end

  def handle_resp({:error, reason}, ref, %{bind_req: ref} = st) do
    :logger.info("Could not bind: #{inspect(reason)}")
    {:noreply, st}
  end

  def handle_resp({:ok, pdu_resp}, ref, st) do
    {{req, _args, _ref}, reqs} = :cl_lists.keyextract(ref, 3, st.reqs)
    :logger.info("Request: #{inspect(req)} Response: #{inspect(pdu_resp)}")

    case :smpp_operation.get_value(:congestion_state, pdu_resp) do
      congestion when congestion > 90 ->
        :logger.info("Peer congested: #{inspect(congestion)}")

      _other ->
        :ok
    end

    {:noreply, %{st | reqs: reqs, success: st.success + 1}}
  end

  def handle_resp({:error, {:command_status, status}}, ref, st) do
    {{req, args, _ref}, reqs} = :cl_lists.keyextract(ref, 3, st.reqs)
    reason = :smpp_error.format(status)
    :logger.info("Request: #{inspect(req)} Status: #{inspect(reason)}")

    case :proplists.get_value(:retries, args, 3) do
      0 ->
        :logger.info("Max retries exceeded: #{inspect(req)}")
        {:noreply, %{st | reqs: reqs, failure: st.failure + 1}}

      n ->
        {_cmd_name, params} = req
        new_args = [{:retries, n - 1} | :proplists.delete(:retries, args)]
        submit(params, new_args, 0)
        {:noreply, %{st | reqs: reqs}}
    end
  end

  def handle_resp({:error, reason}, ref, st) do
    {{req, args, _ref}, reqs} = :cl_lists.keyextract(ref, 3, st.reqs)
    :logger.info("Request: #{inspect(req)} Failure: #{inspect(reason)}")
    {_cmd_name, params} = req
    submit(params, args, 10)
    {:noreply, %{st | reqs: reqs}}
  end

  def handle_unbind(_pdu, _from, st), do: {:reply, :ok, st}

  ### -----------------------------------------------------------------------------
  ### CONNECT EXPORTS
  ### -----------------------------------------------------------------------------
  def bind(:tx), do: :gen_esme.bind_transmitter(__MODULE__, @bind_params, [])
  def bind(:rx), do: :gen_esme.bind_receiver(__MODULE__, @bind_params, [])
  def bind(:trx), do: :gen_esme.bind_transceiver(__MODULE__, @bind_params, [])

  def connect(:outbind, _) do
    :logger.info("Listening at #{@port_listen} for an outbind")
    :gen_esme.listen(__MODULE__, [{:addr, @addr}, {:port, @port_listen}])
  end

  def connect(mode, silent) do
    peer = format_peer(@addr, @port)

    case :gen_esme.open(__MODULE__, @addr, [{:port, @port}]) do
      :ok ->
        :logger.info("Connected to #{inspect(peer)}")
        bind(mode)

      {:error, reason} ->
        :logger.info("Cannot connect to #{inspect(peer)} Error: #{inspect(reason)}")
        :timer.sleep(5000)
        __MODULE__.connect(mode, silent)
    end
  end

  ### -----------------------------------------------------------------------------
  ### FORMAT FUNCTIONS
  ### -----------------------------------------------------------------------------
  def format_peer({a, b, c, d}, port), do: :io_lib.format("~p.~p.~p.~p:~p", [a, b, c, d, port])

  ### -----------------------------------------------------------------------------
  ### INTERNAL FUNCTIONS
  ### -----------------------------------------------------------------------------
  def destination(dest) do
    case :cl_lists.is_deep(dest) do
      false ->
        {:destination_addr, dest}

      true ->
        {:dest_address, :lists.map(fn x -> dest_addr_sme(x) end, dest)}
    end
  end

  def dest_addr_sme(dest_addr), do: :smpp_base.dest_address_sme(1, 1, 1, dest_addr)

  def is_multi(params), do: :proplists.get_value(:destination_addr, params) == :undefined

  def params(src, dest), do: [destination(dest), {:source_addr_ton, 5}, {:source_addr, src}]

  def submit(msg, params, args, priority) when length(msg) > 160 do
    ref_num = :smpp_ref_num.next(__MODULE__)
    l = :smpp_sm.split([{:short_message, msg} | params], ref_num, :udh)
    :lists.foreach(fn x -> submit(x, args, priority) end, l)
  end

  def submit(msg, params, args, priority),
    do: submit([{:short_message, msg} | params], args, priority)

  def submit(params, args, priority) do
    case is_multi(params) do
      true ->
        :gen_esme.queue_submit_multi(__MODULE__, params, args, priority)

      false ->
        :gen_esme.queue_submit_sm(__MODULE__, params, args, priority)
    end
  end
end
