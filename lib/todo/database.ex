defmodule Todo.Database do
  use GenServer

  def start(db_folder) do
    GenServer.start(__MODULE__, db_folder, name: :database_server)
  end

  def store(key, data) do
    key
    |> choose_worker
    |> Todo.DatabaseWorker.store(key, data)
  end

  def get(key) do
    key
    |> choose_worker
    |> Todo.DatabaseWorker.get(key)
  end

  defp choose_worker(key) do
    GenServer.call(:database_server, {:choose_worker, key})
  end

  def init(db_folder) do
    {:ok, start_workers(db_folder)}
  end

  defp start_workers(db_folder) do
    for index <- 1..3, into: HashDict.new do
      {:ok, pid} = Todo.DatabaseWorker.start(db_folder)
      {index - 1, pid}
    end
  end

  def handle_call({:choose_worker, key}, _, workers) do
    worker_key = :erlang.phash2(key, 3)
    {:reply, HashDict.get(workers, worker_key), workers}
  end

  # Needed for testing purposes
  def handle_info(:stop, workers) do
    workers
    |> HashDict.values
    |> Enum.each(&send(&1, :stop))

    {:stop, :normal, HashDict.new}
  end
  def handle_info(_, state), do: {:noreply, state}
end


# defmodule Todo.Database do
#   use GenServer

#   # We are registering the process locally under an alias, :database_server.
#   # This keeps things simple and relives us from passing around the Todo.Database
#   # pid. Of course, the downside is that we can run only one instance of the 
#   # database process.
#   def start(db_folder) do
#     GenServer.start(__MODULE__, db_folder,
#       name: :database_server
#       )
#   end

#   # Using cast promotes scalability of the system because the caller issues
#   # a request and goes about its business. This comes at the cost of consistency
#   # as we can't be confident about whether a request has succeeded.
#   def store(key, data) do
#     GenServer.cast(:database_server, {:store, key, data})
#   end

#   def get(key) do
#     GenServer.call(:database_server, {:get, key})
#   end

#   def init(db_folder) do
#     File.mkdir_p(db_folder)
#     {:ok, db_folder}
#   end

#   def handle_cast({:store, key, data}, db_folder) do
#     file_name(db_folder, key)
#     |> File.write!(:erlang.term_to_binary(data))

#     {:noreply, db_folder}
#   end

#   def handle_call({:get, key}, _, db_folder) do
#     data = case File.read(file_name(db_folder, key)) do
#       {:ok, contents} -> :erlang.binary_to_term(contents)
#       _ -> nil
#     end

#     {:reply, data, db_folder}
#   end

#   defp file_name(db_folder, key), do: "#{db_folder}/#{key}"
# end