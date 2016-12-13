defmodule HttpServerTest do
  use ExUnit.Case, async: false

  setup do
    File.rm_rf("./persist/")
    File.rm_rf("Mnesia.nonode@nohost")
    {:ok, apps} = Application.ensure_all_started(:todo)
    HTTPotion.start

    on_exit fn ->
      Enum.each(apps, &Application.stop/1)
    end

    :ok
  end

  test "http server" do
    assert %HTTPotion.Response{body: "", status_code: 200} =
      HTTPotion.get("http://127.0.0.1:5454/entries?list=test&date=20131219")

    assert %HTTPotion.Response{body: "OK", status_code: 200} =
      HTTPotion.post("http://127.0.0.1:5454/add_entry?list=test&date=20131219&title=Dentist", "")

    assert %HTTPotion.Response{body: "2013-12-19    Dentist\n", status_code: 200} =
      HTTPotion.get("http://127.0.0.1:5454/entries?list=test&date=20131219")
  end
end