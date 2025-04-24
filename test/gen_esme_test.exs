defmodule GenEsmeTest do
  use ExUnit.Case

  @long_sm 'Lorem ipsum dolor sit amet, consectetur adipis cing elit. Ut tristique risus ut elit. Nullam id nulla vitae odio pharetra gravida. Nunc nisl. Integer porttitor vehicula odio. Praesent justo. Donec id.'
  @short_sm 'hello world'

  test "transmitter" do
    {:ok, _mc} = MC.start_link(false)
    {:ok, _esme} = ESME.start_link(:tx, false)

    ESME.reset()
    wait_bound()

    bcast_area = :smpp_base.broadcast_area(0, 'area_name')
    bcast_content_type = :smpp_base.broadcast_content_type(0, 0)
    bcast_freq_interval = :smpp_base.broadcast_frequency_interval(9, 10)

    bcast_params = [
      {:message_id, '1'},
      {:message_payload, @long_sm},
      {:broadcast_area_identifier, [bcast_area]},
      {:broadcast_content_type, bcast_content_type},
      {:broadcast_rep_num, 1},
      {:broadcast_frequency_interval, bcast_freq_interval}
    ]

    ESME.broadcast_sm(bcast_params)
    ESME.cancel_broadcast_sm([{:message_id, '1'}])
    ESME.cancel_sm([{:destination_addr, '0123456789'}, {:message_id, '1'}])

    data_sm_params = [{:destination_addr, '0123456789'}, {:message_payload, @long_sm}]
    ESME.data_sm(data_sm_params)

    query_bcast_params = [
      {:message_id, '1'},
      {:broadcast_area_identifier, [bcast_area]},
      {:broadcast_area_success, [50]}
    ]

    ESME.query_broadcast_sm(query_bcast_params)
    ESME.query_sm([{:message_id, '1'}])

    replace_sm_params = [{:destination_addr, '0123456789'}, {:short_message, @short_sm}]
    ESME.replace_sm([{:message_id, '1'} | replace_sm_params])

    :timer.sleep(5_000)
    dest_addr_sme = fn x -> :smpp_base.dest_address_sme(1, 1, 1, x) end
    nums = :lists.map(dest_addr_sme, ['0123456789', '0234567890', '0345678901'])
    submit_muti_params = [{:short_message, @short_sm}, {:dest_address, nums}]
    ESME.submit_multi(submit_muti_params)

    submit_sm_params = [{:destination_addr, '0123456789'}, {:short_message, @long_sm}]
    ESME.submit_sm(submit_sm_params)

    :timer.sleep(5_000)
    ESME.submit_sm(submit_sm_params)
    ESME.submit_sm(submit_sm_params)

    :timer.sleep(5_000)
    assert 0 == ESME.failure()
    assert 14 == ESME.success()

    ESME.stop()
    MC.stop()
  end

  test "queue" do
    {:ok, _mc} = MC.start_link(false)
    {:ok, _esme} = ESME.start_link(:tx, false)

    wait_bound()

    :ok = ESME.pause()
    :ok = ESME.rps_max(2)
    assert 2 == ESME.rps_max()

    bcast_area = :smpp_base.broadcast_area(0, 'area_name')
    bcast_content_type = :smpp_base.broadcast_content_type(0, 0)
    bcast_freq_interval = :smpp_base.broadcast_frequency_interval(9, 10)

    bcast_params = [
      {:message_id, '1'},
      {:message_payload, @long_sm},
      {:broadcast_area_identifier, [bcast_area]},
      {:broadcast_content_type, bcast_content_type},
      {:broadcast_rep_num, 1},
      {:broadcast_frequency_interval, bcast_freq_interval}
    ]

    ESME.queue_broadcast_sm(bcast_params)
    ESME.queue_broadcast_sm(bcast_params, 0)
    ESME.queue_cancel_broadcast_sm([{:message_id, '1'}])
    ESME.queue_cancel_broadcast_sm([{:message_id, '1'}], 0)

    assert 0 == ESME.rps()
    assert 4 == ESME.queue_len()

    ESME.resume()

    cancel_params = [{:destination_addr, '0123456789'}, {:message_id, '1'}]
    ESME.queue_cancel_sm(cancel_params)
    ESME.queue_cancel_sm(cancel_params, 0)

    data_sm_params = [{:destination_addr, '0123456789'}, {:message_payload, @long_sm}]

    :timer.sleep(1_100)
    assert 2 == ESME.rps()

    :timer.sleep(2_000)
    assert 0 == ESME.queue_len()
    assert [] == ESME.queue_out()

    ESME.pause()
    ESME.queue_data_sm(data_sm_params)
    ESME.queue_data_sm(data_sm_params, 0)

    query_bcast_params = [
      {:message_id, '1'},
      {:broadcast_area_identifier, [bcast_area]},
      {:broadcast_area_success, [50]}
    ]

    ESME.queue_query_broadcast_sm(query_bcast_params)

    assert [{{:data_sm, ^data_sm_params}, _args}] = ESME.queue_out()

    ESME.queue_query_broadcast_sm(query_bcast_params, 0)
    ESME.queue_query_sm([{:message_id, '1'}])
    ESME.queue_query_sm([{:message_id, '1'}], 0)

    submit_sm_params = [{:destination_addr, '0123456789'}, {:short_message, @short_sm}]
    replace_params = [{:message_id, '1'} | submit_sm_params]
    ESME.queue_replace_sm(replace_params)
    ESME.queue_replace_sm(replace_params, 0)

    dest_addr_sme = fn x -> :smpp_base.dest_address_sme(1, 1, 1, x) end
    nums = :lists.map(dest_addr_sme, ['0123456789', '0234567890', '0345678901'])
    submit_multi_params = [{:short_message, @short_sm}, {:dest_address, nums}]
    ESME.queue_submit_multi(submit_multi_params)
    ESME.queue_submit_multi(submit_multi_params, 0)
    ESME.queue_submit_sm(submit_sm_params)
    ESME.queue_submit_sm(submit_sm_params, 0)
    ESME.queue_submit_sm(submit_sm_params)
    ESME.queue_submit_sm(submit_sm_params, 0)
    ESME.queue_broadcast_sm(bcast_params)

    assert 0 == ESME.rps()
    assert 14 == ESME.queue_len()

    ESME.resume()
    ESME.queue_broadcast_sm(bcast_params, 0)
    ESME.queue_cancel_broadcast_sm([{:message_id, '1'}])
    ESME.queue_cancel_broadcast_sm([{:message_id, '1'}], 0)
    ESME.rps_max(1_000)

    :timer.sleep(2_000)

    ESME.pause()
    ESME.queue_cancel_sm(cancel_params)
    ESME.queue_cancel_sm(cancel_params, 0)
    ESME.queue_data_sm(data_sm_params)
    ESME.queue_data_sm(data_sm_params, 0)

    assert [{{:cancel_sm, ^cancel_params}, _args1}, {{:data_sm, ^data_sm_params}, _args2}] =
             ESME.queue_out(2)

    assert 2 == ESME.queue_len()

    ESME.resume()
    ESME.queue_query_broadcast_sm(query_bcast_params)
    ESME.queue_query_sm([{:message_id, '1'}])
    ESME.queue_replace_sm(replace_params)
    ESME.queue_replace_sm(replace_params)
    ESME.queue_submit_sm(submit_sm_params, 0)

    wait_empty()

    assert 0 == ESME.queue_len()

    ESME.stop()
    MC.stop()
  end

  defp wait_bound() do
    if ESME.bound() do
      :ok
    else
      :timer.sleep(3000)
      wait_bound()
    end
  end

  defp wait_empty() do
    case ESME.queue_len() do
      0 ->
        :ok

      _ ->
        :timer.sleep(1_000)
        wait_empty()
    end
  end
end
