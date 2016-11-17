defmodule Todo.Server do
  use GenServer

  def start(name) do
    GenServer.start(Todo.Server, name)
  end

  def add_entry(todo_server, new_entry) do
    GenServer.cast(todo_server, {:add_entry, new_entry})
  end

  def entries(todo_server, date) do
    GenServer.call(todo_server, {:entries, date})
  end

  def init(name) do
    {:ok, {name, Todo.Database.get(name) || Todo.List.new}}
  end

  def handle_cast({:add_entry, new_entry}, {name, todo_list}) do
    new_state = Todo.List.add_entry(todo_list, new_entry)
    Todo.Database.store(name, new_entry)
    {:noreply, {name, new_state}}
  end

  def handle_call({:entries, date}, _, {name, todo_list}) do
    {
      :reply,
      Todo.List.entries(todo_list, date),
      {name, todo_list}
    }
  end
end

#The following comment out code is what the process would look like without using GenServer

# defmodule TodoServer do
#   def start do
#     spawn(fn -> loop(TodoList.new) end)
#     #When u call loop with a new todolist, it will block on the receive call. (ref 1)
#   end

#   def add_entry(todo_server, new_entry) do
#     send(todo_server, {:add_entry, new_entry})
#   end

#   def entries(todo_server, date) do
#     send(todo_server, {:entries, self, date})

#     receive do
#       {:todo_entries, entries} -> entries
#     after 5000 ->
#       {:error, :timeout}
#     end
#   end

#   defp loop(todo_list) do
#     #(ref 1) after the start() call, which calls loop, the loop
#     #method will block on receive, since receive is a blocking call.
#     #But processes blocking do not waste cpu cycles as they are in
#     #a suspended state.
#     new_todo_list = receive do
#       message ->
#         process_message(todo_list, message)
#     end

#     loop(new_todo_list)
#   end

#   defp process_message(todo_list, {:add_entry, new_entry}) do
#     TodoList.add_entry(todo_list, new_entry)
#   end

#   defp process_message(todo_list, {:entries, caller, date}) do
#     send(caller, {:todo_entries, TodoList.entries(todo_list, date)})
#     todo_list
#   end
# end











