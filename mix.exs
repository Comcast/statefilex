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

defmodule Statefilex.Mixfile do
  use Mix.Project

  def project do
    [
      app: :statefilex,
      description: description(),
      version: "0.1.0",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:mix, :logger]]
  end

  defp deps do
    [
      {:eqc_ex, "~> 1.4.2"},
      {:ex_doc, "~> 0.18.3", only: :dev}
    ]
  end

  defp description do
    """
    StateFile is a utility that allows you to store any Elixir term to
    disk in a series of rolling files under a single directory
    """
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["Sean Cribbs", "Zeeshan Lakhani"],
      files: ["lib", "README*", "mix.exs", "CONTRIBUTING", "NOTICE", "LICENSE"],
      links: %{
        "Github" => "https://github.com/Comcast/statefilex"
      }
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
