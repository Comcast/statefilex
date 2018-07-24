# Copyright 2018 Comcast Cable Communications Management, LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule StateFile do
  @moduledoc """
  Persists terms to disk in a directory of a limited number of files.

  ## Examples

      iex> sf = StateFile.new("/tmp/example", 2)
      iex> StateFile.read(sf)
      nil
      iex> StateFile.write(sf, :hello)
      :ok
      iex> StateFile.read(sf)
      {:ok, :hello}
      iex> StateFile.write(sf, :world)
      :ok
      iex> StateFile.write(sf, :goodbye)
      :ok
      iex> {:ok, files} = File.ls("/tmp/example")
      iex> length(files)
      2
      iex> StateFile.read(sf)
      :goodbye

  """

  @file_match ~r/#{__MODULE__}-\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d*Z/

  require Logger

  defstruct directory: nil, max_files: 5

  @opaque t :: %__MODULE__{directory: Path.t(), max_files: non_neg_integer}

  @doc "Initializes a new StateFile."
  @spec new(Path.t(), non_neg_integer) :: t
  def new(directory, max_files) do
    %__MODULE__{directory: directory, max_files: max_files}
  end

  @doc """
  Reads a term from a StateFile directory.

  If there is no readable data, `nil` is returned.
  """
  @spec read(t) :: {:ok, term} | nil
  def read(sf) do
    case ls(sf) do
      file_list when is_list(file_list) ->
        file_list |> Enum.find_value(&read_file/1)

      _err ->
        nil
    end
  end

  @doc """
  Writes a term to the StateFile directory.

  If a file could not be written or old files could not be rotated
  out, `{:error, File.posix()}` will be returned.
  """
  @spec write(t, term) :: :ok | {:error, File.posix()}
  def write(%__MODULE__{directory: dir} = sf, value) do
    with :ok <- File.mkdir_p(dir),
         :ok <- check_permissions(dir),
         :ok <- File.write(next_filename(dir), :erlang.term_to_binary(value)) do
      prune(sf)
    end
  end

  defp next_filename(dir) do
    Path.join(dir, "#{__MODULE__}-#{DateTime.utc_now() |> DateTime.to_iso8601()}")
  end

  defp read_file(file) do
    try do
      contents = file |> File.read!() |> :erlang.binary_to_term()
      {:ok, contents}
    rescue
      file_error in [File.Error] ->
        _ = Logger.error("Could not read file #{file}: #{Exception.message(file_error)}")
        false

      badarg in [ArgumentError] ->
        _ = Logger.error("Data corrupted in file #{file}: #{Exception.message(badarg)}")
        false
    end
  end

  defp prune(%__MODULE__{max_files: max_files} = sf) do
    # Prunes files that exceed `max_files`, keeping only the latest
    case ls(sf) do
      file_list when is_list(file_list) ->
        file_list
        |> Enum.drop(max_files)
        |> Enum.each(&File.rm/1)

      err ->
        err
    end
  end

  @doc false
  def ls(%__MODULE__{directory: dir}) do
    # Lists files in the StateFile directory in reverse order with
    # full paths.
    with {:ok, files} <- File.ls(dir) do
      files
      |> Enum.filter(fn s -> Regex.match?(@file_match, s) end)
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.map(fn f -> Path.join(dir, f) end)
    end
  end

  defp check_permissions(directory) do
    with {:ok, stat} <- File.stat(directory) do
      if stat.access == :read_write do
        :ok
      else
        {:error, :eacces}
      end
    end
  end
end
