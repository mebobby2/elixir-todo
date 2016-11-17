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

  # Todo.Database.get is a long running function as it reads from disk.
  # We need to be careful with long running init/1 callbacks as it will 
  # block the GenServer.start function. Consequently, a long running
  # init/1 function will cause the creator process to block. In this case,
  # a long initiation of to-do server will block the cache process, which 
  # is used by many clients.
  # def init(name) do
  #   {:ok, {name, Todo.Database.get(name) || Todo.List.new}}
  # end

  # To circumvent this problem, we use a simple trick. We send a message 
  # to ourselves in the init call and do the real work in the callback
  # function. This only works for processes that isn't registered under 
  # a local alias. This is because if it isn't register, we can guarantee
  # the message we send to it is the first message in the inbox. If it is
  # registered, an outside process may send a message into the inbox while
  # this process is still being initialized.
  def init(name) do
    send(self, {:real_init, name})
    {:ok, nil}
  end

  def handle_cast({:add_entry, new_entry}, {name, todo_list}) do
    new_state = Todo.List.add_entry(todo_list, new_entry)
    Todo.Database.store(name, new_state)
    {:noreply, {name, new_state}}
  end

  def handle_call({:entries, date}, _, {name, todo_list}) do
    {
      :reply,
      Todo.List.entries(todo_list, date),
      {name, todo_list}
    }
  end

  def handle_info({:real_init, name}, state) do
    {:noreply, {name, Todo.Database.get(name) || Todo.List.new}}
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











