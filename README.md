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

### Processes are bottlenecks

Because a process can only run one piece of code at a time, it becomes a bottleneck. So, though process can synchronise code, manage state, and handle resource reuse, they run sequentially and are a bottleneck in the system. Keep this in mind. There are however many ways to optimise single processes. 

### Limitation of registering processes with local aliases

When registering the process locally under an alias, will keep things simple and relieves us from passing around the process pid. Of course, the downside is that we can run only one instance of the database process.

### Benefits/drawbacks of cast/call

Using cast promotes scalability of the system because the caller issues a request and goes about its business. This comes at the cost of consistency as we can't be confident about whether a request has succeeded. Calls can also be used to apply back pressure to client processes. Because a call blocks a client, it prevents the client from generating too much work. The client becomes synchronized with the server and can never produce more work than the server can handle. In contrast, if you use casts, clients may overload the server, and requests may pile up in the message box and consume memory. Ultimately, you may run out of memory, and the entire VM may be terminated. 

### Hack to circumvent long running init/1 callbacks

A long running function eg it reads from disk needs, to be carefully reasoned about. We need to be careful with long running init/1 callbacks as it will block the GenServer.start function. Consequently, a long running init/1 function will cause the creator process to block. If the creator process is used by many other client processes, then the whole system will be blocked and responsiveness of the system will decrease.  

To circumvent this problem, we use a simple trick. We send a message to ourselves in the init call and do the real work in the callback function. This only works for processes that isn't registered under a local alias. This is because if it isn't register, we can guarantee the message we send to it is the first message in the inbox. If it is registered, an outside process may send a message into the inbox while this process is still being initialized.

```
  def init(name) do
    send(self, {:real_init, name})
    {:ok, nil}
  end

  def handle_info({:real_init, name}, state) do
    {:noreply, {name, Todo.Database.get(name) || Todo.List.new}}
  end
```

### Synchronous Request Timeout Gotchas

If a request is a synchronous call, i.e. handle_call, client processs will need to wait for it. To increase the responsiveness of the system, we can put a timeout on the get call, but this doesn't really speed up the overall system. This is because even if the call times out, the message will still be in the callee's inbox, meaning the callee process will need to reprocess again in the near future, potentially resulting in the same problem.

### Understanding the Receive function

```
  defmodule TodoServer do
    def start do
      spawn(fn -> loop(TodoList.new) end)
      #When u call loop with a new todolist, it will block on the receive call. (ref 1)
    end

    defp loop(todo_list) do
      #(ref 1) after the start() call, which calls loop, the loop
      #method will block on receive, since receive is a blocking call.
      #But processes blocking do not waste cpu cycles as they are in
      #a suspended state.
      new_todo_list = receive do
        message ->
          process_message(todo_list, message)
      end

      loop(new_todo_list)
    end
  end
```

### Pooling

Even though in elixir you can start many processes and perform things in parallel, this might result in degraded performance sometimes. E.g. If the parallel processes perform IO. Increasing the number of concurrent disk-based operations doesn’t in reality yield significant improvements and may hurt performance. In such a case, you would typically need to constrain the number of simultaneous IO operations. And this is the purpose of a pool of processes.

### Elixir error types

Elixir has 3 error types. The usual 'raise'. Then there is 'exit', when u want to terminate a process. And finally, 'throw', which is for non-local returns, such as returning from recursion loop. Other languages usually have constructs such as break, continue, and return for this purpose, but Elixir has none of these. Hence throw is neccessary. But using throw is considered hacky and we should avoid this technique as much as possible. It is bad because this technique is reminiscent of 'goto'. 'goto' leads to spaghetti code. This is why constructs like functions, conditionals, and loops were invented, to replace 'goto'. 

## Upto

Upto page 201

