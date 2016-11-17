# elixir-todo

## To Run

* iex -S mix
* {:ok, cache} = Todo.Cache.start
* bobs_list = Todo.Cache.server_process(cache, "Bob's list")
* Todo.Server.add_entry(bobs_list, %{date: {2013, 12, 19}, title: "Dentist"})
* Todo.Server.entries(bobs_list, {2013, 12, 19})

## Elixir Tips

### What are the reasons for running a piece of code in a dedicated server process?

* The code must manage a long-living state.
* The code handles a kind of a resource that can and should be reused: for example, a TCP connection, database connection, file handle, pipe to an OS process, and so on.
* A critical section of the code must be synchronized. Only one process may run this code in any moment.

If none of these conditions are met, you probably don’t need a process and can run the code in client processes, which will completely eliminate the bottleneck and promote parallelism and scalability.

## Upto

Upto page 197 - Exercise: pooling and synchronizing

