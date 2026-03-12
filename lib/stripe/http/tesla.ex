if Code.ensure_loaded?(Tesla) && Code.ensure_loaded?(Finch) do
  defmodule Stripe.HTTP.Tesla do
    @behaviour Stripe.HTTP

    @adapter {Tesla.Adapter.Finch, name: StripeFinch}

    @client_timeout :timer.seconds(30)

    @impl true
    def request(method, url, headers, body, _opts) do
      {tesla_body, headers} = prepare_body(body, headers)

      case Tesla.request(client(),
             method: method,
             url: url,
             body: tesla_body,
             headers: headers
           ) do
        {:ok, response} ->
          {:ok, response.status, response.headers, response.body}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def supervisor_children do
      [{Finch, name: StripeFinch}]
    end

    defp prepare_body({:multipart, parts}, headers) do
      mp =
        Enum.map(parts, fn
          {:file, content, {"form-data", params}, extra_headers} ->
            name = Keyword.get(params, :name, "file")
            filename = Keyword.get(params, :filename, "upload")

            content_type =
              Enum.find_value(extra_headers, "application/octet-stream", fn
                {"Content-Type", ct} -> ct
                {"content-type", ct} -> ct
                _ -> nil
              end)

            {name, content, [{"Content-Type", content_type}], [name: name, filename: filename]}

          {name, value} ->
            {to_string(name), to_string(value), [], [name: to_string(name)]}
        end)

      filtered_headers =
        Enum.reject(headers, fn {key, _val} ->
          String.downcase(key) == "content-type"
        end)

      {Tesla.Multipart.new() |> add_multipart_parts(mp), filtered_headers}
    end

    defp prepare_body(body, headers), do: {body, headers}

    defp add_multipart_parts(mp, []), do: mp

    defp add_multipart_parts(mp, [{name, content, extra_headers, opts} | rest]) do
      filename = Keyword.get(opts, :filename)

      mp =
        if filename do
          content_type =
            Enum.find_value(extra_headers, "application/octet-stream", fn
              {"Content-Type", ct} -> ct
              _ -> nil
            end)

          Tesla.Multipart.add_file_content(mp, content, filename,
            name: name,
            headers: [{"Content-Type", content_type}]
          )
        else
          Tesla.Multipart.add_field(mp, name, content)
        end

      add_multipart_parts(mp, rest)
    end

    defp client do
      middleware = [
        Tesla.Middleware.OpenTelemetry,
        Tesla.Middleware.DecompressResponse,
        {Tesla.Middleware.Timeout, timeout: @client_timeout}
      ]

      Tesla.client(middleware, @adapter)
    end
  end
end
