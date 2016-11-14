defmodule Todo.CsvImporter do

  def import(file_name) do
    file_name
    |> read_lines
    |> create_entries
    |> Todo.List.new
  end

  defp read_lines(file_name) do
    file_name
    |> File.stream!
    |> Stream.map(&String.replace(&1, "\n", ""))
  end

  def create_entries(lines) do
    lines
    |> Stream.map(&extract_fields/1)
    |> Stream.map(&create_entry/1)
  end

  defp extract_fields(line) do
    line
    |> String.split(",")
    |> convert_date
  end

  defp convert_date([date_string, title]) do
    {parse_date(date_string), title}
  end

  defp parse_date(date_string) do
    date_string
    |> String.split("/")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple
  end

  defp create_entry({date, title}) do
    %{date: date, title: title}
  end

end