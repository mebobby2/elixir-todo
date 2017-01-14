defmodule Todo.Cache do
  def server_process(todo_list_name) do
    #By looking up whether the process is already there first, you can reduce the node chatter.
    # Recall that a lookup is done locally in an internal ETS table. This means you can quickly verify
    # whether the process exists and avoid chatting with other nodes if the process is already registered.
    case Todo.Server.whereis(todo_list_name) do
      :undefined -> create_server(todo_list_name)
      pid -> pid
    end
  end

  defp create_server(todo_list_name) do
    case Todo.ServerSupervisor.start_child(todo_list_name) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end