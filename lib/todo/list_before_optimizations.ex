# defmodule Todo.List do
#   defstruct auto_id: 1, entries: HashDict.new

#   def new(entries \\ []) do
#     Enum.reduce(
#       entries,
#       %Todo.List{},
#       &add_entry(&2, &1)
#     )
#   end

#   def size(todo_list) do
#     HashDict.size(todo_list.entries)
#   end

#   def add_entry(
#     %Todo.List{entries: entries, auto_id: auto_id} = todo_list,
#     entry
#     ) do
#     entry = Map.put(entry, :id, auto_id)
#     new_entries = HashDict.put(entries, auto_id, entry)

#     %Todo.List{todo_list |
#       entries: new_entries,
#       auto_id: auto_id + 1
#     }
#   end

#   def update_entry(todo_list, %{} = new_entry) do
#     update_entry(todo_list, new_entry.id, fn(_) -> new_entry end)
#   end

#   def update_entry(
#     %Todo.List{entries: entries} = todo_list,
#     entry_id,
#     updater_func) do
#     case entries[entry_id] do
#       nil -> todo_list
#       old_entry ->
#         old_entry_id = old_entry.id
#         new_entry = %{id: ^old_entry_id} = updater_func.(old_entry)
#         new_entries = HashDict.put(entries, new_entry.id, new_entry)
#         %Todo.List{todo_list | entries: new_entries}
#     end

#   end

#   def entries(%Todo.List{entries: entries}, date) do
#     entries
#     |> Stream.filter(fn({_, entry}) ->
#         entry.date == date
#        end)
#     |> Enum.map(fn({_, entry}) ->
#         entry
#        end)
#   end

#   def delete_entry(
#     %Todo.List{entries: entries} = todo_list,
#     entry_id) do
#     %Todo.List{todo_list | entries: HashDict.delete(entries, entry_id)}
#   end
# end

# # Example to use in list comprehensions
# # entries = [
# #           %{date: {2013, 12, 19}, title: "Dentist"},
# #           %{date: {2013, 12, 20}, title: "Shopping"},
# #           %{date: {2013, 12, 19}, title: "Movies"}
# # ]
# # for entry <- entries, into: TodoList.new, do: entry

# defimpl Collectable, for: TodoList do
#   def into(original) do
#     {original, &into_callback/2}
#   end

#   defp into_callback(todo_list, {:cont, entry}) do
#     TodoList.add_entry(todo_list, entry)
#   end
#   defp into_callback(todo_list, :done), do: todo_list
#   defp into_callback(_todo_list, :halt), do: :ok
# end