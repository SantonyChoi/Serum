defmodule Serum.DevServer.Service.GenServerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import Serum.TestHelper
  alias Serum.DevServer
  alias Serum.DevServer.Service.GenServer, as: GS
  alias Serum.IOProxy

  # IMPORTANT NOTE: PLEASE MAKE SURE THE TCP PORT 8080 IS NOT IN USE
  #                 BEFORE RUNNING THIS TEST.

  setup do
    tmp_dir = get_tmp_dir("serum_test_")
    pid = start_supervised!(%{id: :ignore_io, start: {StringIO, :open, [""]}})
    test_sup! = hd(Process.info(self())[:links])
    old_group_leader! = Process.info(test_sup!)[:group_leader]
    {:ok, io_config} = IOProxy.config()

    make_project(tmp_dir)
    Process.group_leader(test_sup!, pid)
    start_supervised!(%{id: :dev_server, start: {DevServer, :run, [tmp_dir, 8080]}})
    Process.group_leader(test_sup!, old_group_leader!)
    IOProxy.config(mute_err: false)
    on_exit(fn ->
      IOProxy.config(Keyword.new(io_config))
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "if source_dir/0 returns the source directory", %{tmp_dir: tmp_dir} do
    source_dir = GS.source_dir()
    assert Path.basename(source_dir) === Path.basename(tmp_dir)
  end

  test "if site_dir/0 returns the temp output directory" do
    site_dir = GS.site_dir()
    assert String.contains?(site_dir, "serum_")
    assert Path.dirname(site_dir) === Path.expand(System.tmp_dir!())
  end

  test "if port/0 returns the current port" do
    assert 8080 === GS.port()
  end

  test "if dirty?/0 returns the current file system status" do
    assert is_boolean(GS.dirty?())
  end

  test "if subscribe/0 adds the calling process to its subscriber state" do
    GS.subscribe()

    pid = self()
    state = :sys.get_state(GS)

    assert Enum.any?(state.subscribers, fn {_, subscriber} -> subscriber === pid end)
  end

  test "if rebuild/0 successfully builds the project" do
    err = capture_io(:stderr, fn -> GS.rebuild() end)

    assert "" === String.trim(err)
  end

  test "if a build process initiated by rebuild/0 may fail", %{tmp_dir: tmp_dir} do
    serum_exs = Path.join(tmp_dir, "serum.exs")
    File.rename(serum_exs, serum_exs <> "_")

    err =
      capture_io(:stderr, fn ->
        assert :ok = GS.rebuild()
      end)

    assert String.contains?(err, "Error occurred while building the website")
    File.rename(serum_exs <> "_", serum_exs)
  end
end
