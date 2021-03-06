defmodule RigInboundGateway.ApiProxy.ResponseFromParser do
  @moduledoc """
  Handles parsing of messages coming from different sources (e.g. Kafka)

  """

  require Logger

  alias Rig.Connection.Codec

  # ---

  @spec parse([{String.t(), String.t()}, ...], map()) ::
          {pid, pos_integer(), any()} | String.t()

  def parse(
        headers,
        message
      ) do
    with headers_map <- Enum.into(headers, %{}),
         {:ok, correlation_id} <- Map.fetch(headers_map, "rig-correlation"),
         {:ok, deserialized_pid} <- Codec.deserialize(correlation_id),
         {:ok, raw_response_code} <- Map.fetch(headers_map, "rig-response-code"),
         # forward extra haeders such as content-type
         extra_headers <- Map.drop(headers_map, ["rig-correlation", "rig-response-code"]),
         # convert status code to int if needed, HTTP headers can't have number as a value
         {:ok, response_code} <- to_int(raw_response_code),
         response_body <- try_encode(message) do
      Logger.debug(fn ->
        "Parsed binary HTTP response: body=#{inspect(response_body)}, code=#{
          inspect(response_code)
        }, headers=#{inspect(extra_headers)}"
      end)

      {deserialized_pid, response_code, response_body, extra_headers}
    else
      err -> err
    end
  end

  # ---

  defp try_encode(message) when is_binary(message), do: message

  defp try_encode(message) do
    case Jason.encode(message) do
      {:ok, val_map} ->
        val_map

      _ ->
        message
    end
  end

  # ---

  defp to_int(value) when is_integer(value), do: {:ok, value}

  defp to_int(string) when is_binary(string) do
    {:ok, String.to_integer(string)}
  rescue
    ArgumentError -> {:error, {:not_an_integer, string}}
  end
end
