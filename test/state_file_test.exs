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

defmodule StateFileTest do
  @moduledoc false

  use ExUnit.Case
  use EQC.StateM
  use EQC.ExUnit

  defmodule State do
    @moduledoc false
    defstruct(
      state: nil,
      files: [],
      max_files: 0,
      directory: nil,
      writeable: true,
      readable: true,
      spurious: 0
    )
  end

  defmodule FileValue do
    @moduledoc false
    defstruct value: nil, readable: true, writeable: true, corrupt: false
  end

  setup_all do
    Logger.remove_backend(:console)
    on_exit(fn -> Logger.add_backend(:console) end)
  end

  #################
  # INITIAL STATE
  #################
  def initial_state do
    %State{}
  end

  #################
  # COMMAND: new - creates a new StateFile
  #################
  def new_pre(s) do
    s.state == nil
  end

  def new_args(s) do
    [
      s.directory,
      such_that(max_files <- nat(), do: max_files > 0)
    ]
  end

  def new(directory, max_files) do
    StateFile.new(directory, max_files)
  end

  def new_next(s, res, [dir, max_files]) do
    %State{s | state: res, directory: dir, max_files: max_files}
  end

  #################
  # COMMAND: read - fetches the current state
  #################
  def read_pre(s) do
    s.state != nil
  end

  def read_args(%State{state: sf}) do
    [sf]
  end

  def read(sf) do
    StateFile.read(sf)
  end

  def read_next(s, _res, [_sf]) do
    s
  end

  def read_post(s, [_sf], res) do
    good_files = Enum.filter(s.files, &(&1.readable && !&1.corrupt))

    if good_files == [] || !s.readable do
      satisfy(res == nil)
    else
      satisfy(res == {:ok, hd(good_files).value})
    end
  end

  #################
  # COMMAND: write - writes a new state
  #################
  def write_pre(s) do
    s.state != nil
  end

  def write_args(s) do
    [s.state, nat()]
  end

  def write(sf, value) do
    StateFile.write(sf, value)
  end

  def write_next(s, _res, [_sf, value]) do
    if s.writeable && s.readable do
      new_value = %FileValue{value: value}
      %State{s | files: Enum.take([new_value | s.files], s.max_files)}
    else
      s
    end
  end

  def write_post(s, _args, res) do
    if s.writeable && s.readable do
      satisfy(:ok == res)
    else
      satisfy({:error, :eacces} == res)
    end
  end

  #################
  # COMMAND: corrupt - corrupts a random file
  #################
  def corrupt_pre(s) do
    s.state != nil && Enum.any?(s.files, &(!&1.corrupt)) && s.readable && s.writeable
  end

  def corrupt_pre(s, [_, idx]) do
    idx < length(s.files) && Enum.at(s.files, idx).writeable
  end

  def corrupt_args(s) do
    uncorrupted_files =
      s.files
      |> Enum.with_index()
      |> Enum.reject(&elem(&1, 0).corrupt)

    chosen_file_idx = let({_file, idx} <- elements(uncorrupted_files), do: idx)
    [s.directory, chosen_file_idx]
  end

  def corrupt(directory, idx) do
    {:ok, files} = File.ls(directory)

    file_to_corrupt =
      files
      |> filter_spurious
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.map(fn f -> Path.join(directory, f) end)
      |> Enum.at(idx)

    File.write!(file_to_corrupt, "CORRUPT")
  end

  def corrupt_next(s, _res, [_dir, idx]) do
    %State{s | files: List.update_at(s.files, idx, &%FileValue{&1 | corrupt: true})}
  end

  def corrupt_post(_s, _args, res) do
    satisfy(res == :ok)
  end

  #################
  # COMMAND: directory_permission - set permissions on the directory
  #################
  def directory_permission_args(s) do
    [[directory: s.directory, readable: bool(), writeable: bool()]]
  end

  def directory_permission(directory: directory, readable: readable, writeable: writeable) do
    _ = File.mkdir_p(directory)
    File.chmod(directory, permissions(readable, writeable))
  end

  def directory_permission_next(s, _res, [
        [directory: _dir, readable: readable, writeable: writeable]
      ]) do
    %State{s | readable: readable, writeable: writeable}
  end

  #################
  # COMMAND: spurious - inject a non-managed file into the directory
  #################
  def spurious_pre(s) do
    s.writeable
  end

  def spurious_args(s) do
    [s.directory, s.spurious]
  end

  def spurious(directory, spurious) do
    _ = File.mkdir_p(directory)
    # Pick a filename
    fname = Path.join(directory, "spurious-#{spurious}")
    # Write the file
    File.write!(fname, "SPURIOUS")
  end

  def spurious_next(s, _res, [_dir, count]) do
    %State{s | spurious: count + 1}
  end

  #################
  # COMMAND: file_permission - change permissions on a file
  #################
  def file_permission_pre(s) do
    s.files != [] && s.readable
  end

  def file_permission_pre(s, [args]) do
    args[:index] < length(s.files)
  end

  def file_permission_args(s) do
    index = choose(0, length(s.files) - 1)

    [
      [
        directory: s.directory,
        index: index,
        readable: bool(),
        writeable: bool()
      ]
    ]
  end

  def file_permission(directory: dir, index: idx, readable: r, writeable: w) do
    {:ok, files} = File.ls(dir)

    file_to_mutate =
      files
      |> filter_spurious
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.map(fn f -> Path.join(dir, f) end)
      |> Enum.at(idx)

    if file_to_mutate do
      File.chmod!(file_to_mutate, file_permissions(r, w))
    else
      throw({:badfile, [files: files, index: idx]})
    end
  end

  def file_permission_next(s, _res, [[directory: _dir, index: idx, readable: r, writeable: w]]) do
    %State{s | files: List.update_at(s.files, idx, &%FileValue{&1 | readable: r, writeable: w})}
  end

  #################
  # INVARIANT: We never keep more than `max_files` on disk
  #################
  def invariant(%State{directory: dir, max_files: mf, files: values, readable: r}) do
    case File.ls(dir) do
      {:ok, files} ->
        satisfy(mf >= length(filter_spurious(files)))

      {:error, :eacces} ->
        satisfy(false == r)

      _ ->
        satisfy(values == [])
    end
  end

  #################
  # WEIGHTS: Do mostly reads and writes
  #################
  weight(_, read: 5, write: 8, corrupt: 2)

  #################
  # PROPERTY
  #################
  @tag min_time: 30_000
  property "StateFile" do
    init_state = %State{directory: state_dir()}

    forall cmds <- commands(__MODULE__, init_state) do
      File.chmod(init_state.directory, 0o700)
      File.rm_rf!(init_state.directory)
      result = run_commands(__MODULE__, cmds)
      check_commands(__MODULE__, cmds, result)
    end
  end

  ##########
  # Utility functions
  ##########
  defp state_dir do
    "/tmp/#{__MODULE__}/#{System.monotonic_time()}"
  end

  defp filter_spurious(files) do
    Enum.reject(files, fn f -> String.starts_with?(f, "spurious-") end)
  end

  defp permissions(r, w) do
    # We always want executable on the directory
    ((r && 0o400) || 0) + ((w && 0o200) || 0) + 0o100
  end

  defp file_permissions(r, w) do
    permissions(r, w) - 0o100
  end
end
