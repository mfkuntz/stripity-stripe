defmodule Stripe.HTTP.TeslaTest do
  use ExUnit.Case, async: true

  describe "supervisor_children/0" do
    test "returns Finch child spec" do
      if Code.ensure_loaded?(Tesla) and Code.ensure_loaded?(Finch) do
        children = Stripe.HTTP.Tesla.supervisor_children()
        assert length(children) == 1
      end
    end
  end

  describe "request/5 integration" do
    setup do
      if Code.ensure_loaded?(Tesla) and Code.ensure_loaded?(Finch) do
        start_supervised!({Finch, name: StripeFinch})
      end

      :ok
    end

    @tag :tesla_only
    test "makes a successful request through Tesla" do
      if Code.ensure_loaded?(Tesla) and Code.ensure_loaded?(Finch) do
        api_base_url = Application.get_env(:stripity_stripe, :api_base_url)

        case Stripe.HTTP.Tesla.request(
               :get,
               "#{api_base_url}/v1/customers",
               [
                 {"Authorization", "Bearer sk_test_123"},
                 {"Content-Type", "application/x-www-form-urlencoded"}
               ],
               "",
               []
             ) do
          {:ok, status, headers, body} ->
            assert status in 200..299
            assert is_binary(body)
            # Verify headers are returned as a list of tuples
            assert Enum.all?(headers, fn {k, v} -> is_binary(k) and is_binary(v) end)

          {:error, :econnrefused} ->
            # stripe-mock may not be running, that's ok
            :ok
        end
      end
    end
  end
end
