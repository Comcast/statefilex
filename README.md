# statefilex

`statefilex` is a utility that allows you to store any Elixir term to
disk in a series of rolling files under a single directory. This is
useful for snapshotting the state of a process and recovering that
state at a later time without requiring an external dependency like a
database.

## Installation

`statefilex` is available for installation from [Hex](https://hexdocs.pm/statefilex). The package can be installed
by adding `statefilex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statefilex, "~> 0.1.0"}
  ]
end
```

## Example

``` elixir
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
```

## Testing

Testing requires a full QuickCheck license as the only test is a
(quite exhaustive) stateful property.

## Documentation

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm) at
[https://hexdocs.pm/statefilex](https://hexdocs.pm/statefilex).

## Contributing

If you would like to contribute code to this project you can do so
through GitHub by forking the repository and sending a pull
request. Before Comcast merges your code into the project you must
sign the Comcast Contributor License Agreement (CLA). If you haven't
previously signed a Comcast CLA, you'll automatically be asked to when
you open a pull request. Alternatively, we can e-mail you a PDF that
you can sign and scan back to us. Please send us an e-mail or create a
new GitHub issue to request a PDF version of the CLA.

## Copyright & License

Copyright 2018 Comcast Cable Communications Management, LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

This product includes software developed at Comcast (http://www.comcast.com/).
