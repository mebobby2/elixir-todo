# elixir-todo

## To Run

* iex -S mix
* Todo.Supervisor.start_link
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

### Supervisors localise impact

Supervisors allow you to localize the impact of an error, keeping unrelated parts of the system undisturbed.

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

### Try and tail calls

You may recall the tail-call optimization from chapter 3. If the last thing a function does is call another function (or itself), then a simple jump will occur without a stack push. This optimization isn’t possible if the function call resides in a try con- struct. This is fairly obvious, because the last thing a function does is a try block, and it won’t finish until its do or catch block is done. Consequently, whatever is called in try isn’t the last thing a function does and is therefore not available for tail-call optimization.

### Let it crash

In a complex system, most bugs are flushed out in the testing phase. The remaining bugs mostly fall into a so-called Heisenbug cate- gory—unpredictable errors that occur irregularly in special circumstances and are hard to reproduce. The cause of such errors usually lies in corruptness of the state. Therefore, a reasonable remedy for such errors is to let the process crash and start another one.

This may help, because you’re getting rid of the process state (which may be cor- rupt) and starting with a clean state. In many cases, doing so resolves the immediate problem. Of course, the error should be logged so you can analyze it later and detect the root cause. But in the meantime, you can recover from an unexpected failure and continue providing service. This is a property of a self-healing system.

Because processes share no memory, a crash in one process won’t leave memory garbage that might corrupt another process. Therefore, by running independent actions in separate processes, you automatically ensure isolation and protection.

### Aliases allow process discovery

It’s important to explain why you register the to-do cache under a local alias. You should always keep in mind that in order to talk to a process, you need to have its pid. In chapter 7, you used a naive approach, somewhat resembling that of typical OO systems, where you created a process and then passed around its pid. This works fine until you enter the supervisor realm.

The problem is that supervised processes can be restarted. Remember that restart- ing boils down to starting another process in place of the old one—and the new pro- cess has a different pid. This means any reference to the pid of the crashed process becomes invalid, identifying a nonexistent process. This is why registered aliases are important. They provide a reliable way of finding a process and talking to it, regard- less of possible process restarts.

### Linking all processes

When the supervisor restarts a worker process, you’ll get a completely separate process hierarchy, and there will be a new set of server processes that are in no way related to the previous ones. The previous servers will be unused garbage that are still running and consuming both memory and CPU resources. That is why its important to link related processes. Links ensure that dependent processes are terminated as well, which keeps the system consistent.

### Modifying lists

When you modify the nth element of a list, the new version will contain shallow copies of the first n – 1 elements, followed by the modified element. After that, the tails are completely shared. This is precisely why adding elements to the end of a list is expensive. To append a new element at the tail, you have to iterate and (shallow) copy the entire list! In contrast, pushing an element to the top of a list doesn’t copy anything, which makes it the least expensive operation

### Rich process discovery

If we had one process, lets call it A, that is responsible for starting (start_link) a number of worker processes and keeping track of their pids, and process A is being supervised. If one worker process dies, we must restart all the worker processes. This is because the error from the worker process will be trapped in process A's supervisor, and the supervisor will restart process A, which in turn will restart all the workers.

How do we make sure that a crash in one worker process do not take down the entire supervision tree? We supervise each of the worker process themselves. But in order to be supervised, a worker process must be registered under an alias, and not a pid. This is a property of the Supervisor pattern, You can’t keep a process’s pid for a long time, because that process might be restarted, and its successor will have a different pid.

We use a process registry to achieve this. Every time a process is created, it can register itself to the registry under an alias. If a process is terminated and restarted, the new process will re-register itself. So, having a registry will give you a fixed point where you can discover processes (their pids).

### Avoiding process restarting

By default, a supervisor restarts a terminated process, regardless of the exit reason. Even if the process terminates with the reason :normal, it will be restarted. Sometimes you may want to alter this behavior.

For example, consider a process that handles an HTTP request or a TCP connec- tion. If such a process fails, the socket will be closed, and there’s no point in restarting the process (the remote party will be disconnected anyway). Regardless, you want to have such processes under a supervision tree, because this makes it possible to termi- nate the entire supervisor subtree without leaving dangling processes. In this situa- tion, you can set up a temporary worker by using worker(module, args, restart: :temporary) in the supervisor specification. A temporary worker isn’t restarted on termination.

Another option is a transient worker, which is restarted only if it terminates abnor- mally. Transient workers can be used for processes that may terminate normally, as part of the standard system workflow. For example, in the caching scheme, you use to- do server processes to keep to-do lists in memory. You may want to terminate individ- ual servers normally if they haven’t been used for a while. But if a server crashes abnormally, you want to restart it. This is exactly how transient workers function. A transient worker can be specified with worker(module, args, restart: :transient).

### Let it crash

Let it crash can initially seem confusing, and people may mistake it for the let everything crash approach. There are two important situations in which you should explicitly handle an error:
* Critical processes that shouldn’t crash. Keep code in these processes as simple and short as possible so there are less chances of it crashing. Also, it makes sense to use defensive try/catch statements in each handle_* callback of critical processes.
* An error that can be dealt with in a meaningful way. Look at the :get request in the database worker:
```
def handle_call({:get, key}, _, db_folder) do
  data = case File.read(file_name(db_folder, key)) do
    {:ok, contents} -> :erlang.binary_to_term(contents)
    _ -> nil
  end
  {:reply, data, db_folder}
end

```
When handling a get request, you try to read from the file, covering the case when this reading fails. If you don’t succeed, you return nil, treating this case as if an entry for the given key isn’t in the database.

You can do better. Consider using an error only when a file isn’t available. This error is identified with {:error, :enoent}, so the corresponding code would look like this:
```
case File.read(...) do
  {:ok, contents} -> do_something_with(contents)
  {:error, :enoent} -> nil
end
```
If neither of these two expected situa- tions happens, a pattern match will fail, and so will your process. This is the idea of let it crash. You deal with expected situations (the file is either available or doesn’t exist), ignoring anything else that can go wrong (for example, you don’t have permissions). Personally, I don’t even regard this as error handling. It’s a normal execution path— an expected situation that can and should be dealt with. It’s certainly not something you should let crash.

In contrast, when storing data, you use File.write!/2 (notice the exclamation), which may throw an exception and crash the process. If you didn’t succeed in saving the data, then your database worker has failed, and there’s no point in hiding this fact. Better to fail fast, which will cause an error that will be logged and (hopefully) noticed and fixed.

As a general rule, if you know what to do with an error, you should definitely han- dle it. Otherwise, for anything unexpected, let the process crash, and ensure proper error isolation and recovery via supervisors.

### ETS tables

ETS is a separate memory-data structure where you can store Erlang terms. This makes it possible to share the system-wide state without introducing a dedicated server process. ETS tables are powered by C code, which ensures better speed and efficiency.

### Indepedent operations

The moral of the story is to try and run independent operations in separate pro- cesses. This will ensure that available CPUs are used as much as possible and promote scalability of your system.

## Upto

Upto page 247 - chapter 10

