# elixir-todo

## To Run

### Start server
* iex -S mix

### Starting a cluster
* terminal 1: iex --sname node1@localhost -S mix
* terminal 2: iex --erl "-todo port 5555" --sname node2@localhost -S mix
* terminal 2: Node.connect(:node1@localhost)

### Use classes directly
* bobs_list = Todo.Cache.server_process(cache, "Bob's list")
* Todo.Server.add_entry(bobs_list, %{date: {2013, 12, 19}, title: "Dentist"})
* Todo.Server.entries(bobs_list, {2013, 12, 19})

### Use HTTP interface
* POST http://localhost:5454/add_entry?list=bob&date=20170120&title=Fundraiser
* GET http://localhost:5454/entries?list=bob&date=20170120

### To make a release
* mix deps.get (if added new libs)
* MIX_ENV=prod mix compile --no-debug-info
* MIX_ENV=prod mix release
* rel/todo/bin/todo start (starts the system)


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

Supervisors allow you to localize the impact of an error, keeping unrelated parts of the system undisturbed. It's important to build a supervision tree so that when parts of your application fails, it does not affect the unrelated parts and your system can still go on providing partial service to users.

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

An ETS table are a mutable data structure where you can store tuples.

ETS tables reside in a separate memory space and can be accessed concurrently by many processes.

When sharing data among many processes, consider using ETS for better performance and scalability. Be careful about concurrent writes, and try to serialize writes to the same table (or to the same row) through the single process.

### Indepedent operations

The moral of the story is to try and run independent operations in separate pro- cesses. This will ensure that available CPUs are used as much as possible and promote scalability of your system.

### Compiling

Once you compile your project, compiled binaries reside in the _build/ProjectEnv folder, where ProjectEnv is the mix project environment that was in effect during compilation. (MIX_ENV=prod mix compile)

In addition to your application, the lib folder contains your compile-time dependen- cies. Other runtime dependencies (such as Elixir/Erlang standard applications) already reside someplace else on the disk and are accessible via the load path.

The application resource file resides in lib/YourApp/ebin and is named as YourApp.app. For the to-do system, the file resides in _build/dev/lib/todo/ ebin/ (relative to the root project folder). When you attempt to start the application, the generic application behaviour looks for the resource file in the load paths (the same paths that are searched for compiled binaries).

### Hex

Dependencies are fetched from Elixir’s external package manager, which is called Hex. Other possi- ble dependency sources include the GitHub repository, a git repository, or a local folder.

### Deps

Running deps.get fetches all dependencies (recursively) and stores the reference to the exact version of each dependency in the mix.lock file, unless mix.lock already exists on the disk, in which case this file is consulted to fetch the proper versions of dependencies. This ensures reproducible builds across different machines, so make sure you include mix.lock into the source control where your project resides.

### Cowboy

Cowboy server will run various processes. There will be at least one process that listens on a given port and accepts requests. Then, each distinct TCP connection will be handled in a separate process, and your callbacks (which you have to implement) will be invoked in those request specific processes.

Notice that, despite this elaborate process structure, you don’t set up a supervision tree. You call the http/3 function and disregard the result. Why is that? Because Cowboy takes it upon itself to supervise processes it creates. To be more accurate, most processes reside in the supervision tree of the Ranch application, an internal dependency of Cowboy where TCP/SSL communication is handled.

### Applications are Singletons

OTP Applications are singletons — you can start only one instance of a distinct application in a running BEAM instance.

This fact doesn’t mean you can run only one HTTP server in your system. The Cowboy application can be considered a factory for HTTP servers. When you start the Cowboy application, the supervision tree is set up, but no HTTP server is started yet.

Only when you call Plug.Adapters.Cowboy.http/3 is a separate set of processes started and placed in the Ranch supervision tree. This means you can call http/3 as many time as you want (providing a different port, of course). You could, for example, just as easily start an additional HTTPS server or run multiple unrelated servers from the same BEAM instance.

### Calls vs Casts

Using calls can be a reasonable first attempt because it promotes consistency. Later, you can easily switch to casts or introduce an intermediate process, depending on the specific situation.

Intermediate process: The idea is to provide an immediate response stating that the request has been queued. Then you do your best to process the request, and you send a subsequent notification about the request’s status.

This scheme is definitely more elaborate and involved, so it’s not appropriate for simpler cases where using plain calls is enough. But in cases when the load is very high and end-to-end operations can take longer, introducing an intermediate process may be beneficial. This process can increase the responsiveness of the system while retain- ing consistency. Moreover, this process can serve as a proactive agent in dealing with congestion and increased load. If the system becomes overloaded and the queue starts piling up, you can refuse to take more requests in the queue process until you regain some breathing space.

### OTP vs Lib

An OTP application is a reusable component. The application can run the entire supervision tree or just provide utility modules (as a library application). A non-library application is a callback module that must start the supervision
tree.

### Fully connected cluster

BEAM by default tries to establish a fully connected cluster. If you start a node node3 and connect it to node2, a connection is established to all other nodes that node2 is connected to.

### Group leader process

All standard I/O calls (such as IO.puts/1) are forwarded to the group leader—a process that’s in charge of performing the actual input or output. A spawned process inherits the group leader from the process that spawned it. This is true even when you’re spawning a process on another node. Therefore, your process may run on node2, but its group leader is still on node1. As a consequence, the string to be printed is created on node2 (as the string contents prove), but the output is printed on node1.

### Recognizing remote processes

It should be obvious by now that a pid identifies both a local and a remote process. In almost all cases, you don’t need to worry about the physical location of a process. But it’s worth mentioning some network-specific details about pids.

All the pids you’ve seen up to now have had a similar form: <0.X.0>, where X is a positive integer. Internally, each process has a node-wide unique identifier. This iden- tifier can be seen in the last two numbers of the string representation. If you create enough processes on a single node, the third number will also be greater than zero.

The first number represents the node number—an internal identifier of the node where the process is running. When this number is zero, the process is from the local node. Conversely, when output includes a pid in the form <X.Y.Z> and X isn’t zero, you can be sure it’s a remote process.

### Global Process registration

When a registration is being performed, all nodes are contacted, and they cache the registration information in their local ETS tables. Each subsequent lookup on any node is performed on that node, without any additional chatter. This means a lookup can be performed quickly, whereas registration requires chatting between nodes.

### Groups of processes

Another frequent discovery pattern occurs when you want to register multiple pro- cesses under the same alias. This may sound strange, but it’s useful in situations where you want to categorize processes in the cluster and broadcast messages to all the pro- cesses in a category.

For example, in redundant clusters, you want to keep multiple copies of the same data. Having multiple copies allows you to survive node crashes. If one node termi- nates, a copy should exist somewhere else in the cluster.

### When to use locks

Locking is something you should usually avoid, because it causes the same kinds of problems as classical synchronization approaches. Excessively relying on locks increases the possibility of deadlocks, livelocks, or starvation. Most often, you should synchronize through processes, because it’s easier to reason about the system this way.

But, used judiciously, locks can sometimes improve performance. Remember that message passing has an associated cost; this is especially true in distributed systems, where a message must be serialized and transmitted over the network. If a message is very large, this can introduce significant delays and hurt system performance.

Locks can help here, because they let you synchronize multiple processes on dif- ferent nodes without needing to send large messages to another process.

Let’s say you need to ensure that the processing of a large amount of data is serialized in the entire cluster (at any point in time, at most one process may run in the entire cluster). Normally, this is done by passing the data to a process that acts as a synchronization point. But passing a large chunk of data may introduce a per- formance penalty because data must be copied and transmitted over the network. To avoid this, you can synchronize different processes with locks and then process the data in the caller context

### Different ways for process registration

You may be puzzled by all these different registration facilities, so let’s recall the key differences. The basic registration facility is a local registration that allows you to use a simple atom as an alias to the single process on a node. gproc extends this by letting you use rich aliases—any term can be used as an alias. gproc is more suit- able for single-node registrations, although it does provide support for global regis- trations as well.

Reaching for :global allows you to register a cluster-wide alias. Finally, :pg2 is use- ful to register multiple processes behind a cluster-wide alias (process group), which is usually suitable for pub-sub scenarios.

### Automatic synchronization of registration

I mentioned earlier that global registration sets a cluster-wide lock, and the reg- istration is done in the synchronized piece of code. At any point, there can be at most one process in the entire cluster performing the registration. Therefore, you don’t need to synchronize the registration code yourself. You can safely call multiple simultaneous global registrations of the same alias, and the first one will win; other processes competing for the same alias won’t succeed.

### Alternative to global registration

Keep in mind that global registration is chatty and serialized (only one process at a time may perform global registration). This means the approach you used isn’t very scalable with respect to the number of different to-do lists or the number of nodes in the cluster. The solution will also perform poorly if the network is slow.

Of course, there are alternatives. The main challenge here is to reliably discover the process responsible for a to-do list while reducing network communication. This can be done by introducing a rule that always maps the same to-do list name to the same node in the network. Here’s a simple sketch of the idea:

```
def node_for_list(todo_list_name) do
  all_sorted_nodes = Enum.sort(Node.list([:this, :visible]))
  node_index = :erlang.phash2(
    todo_list_name,
    length(all_sorted_nodes)
  )
  Enum.at(all_sorted_nodes, node_index)
end
```

You get the list of all nodes and sort it to ensure that it’s always in the same order. Then you hash the input name, making sure the result falls in the range 0..length(all_sorted_nodes). Finally, you return the node at the given position. This ensures that as long as the cluster is stable (the list of nodes doesn’t change), the same to-do list will always be mapped to the same node.

Now you can make a discovery in a single hop to the single node by forwarding to the target node and retrieve the desired process there. Like so:

```
node_for_list(todo_list_name)
|> :rpc.call(Todo.Cache, :server_process, [todo_list_name])
```

The benefit is that you can discover the pid with less chatting.

The main downside of this approach is that it doesn’t work properly when the cluster configuration changes. If you add another node or a node disconnects, the mapping rules will change. Dealing with this situation is complex. You need to detect the change in the cluster and migrate all data to different nodes according to new mapping rules. While this data is being migrated, you’ll probably want to keep the service running, which will introduce another layer of complexity. The amount of data that needs to be migrated can be greatly reduced if you use some form of consistent hashing (http://en.wikipedia.org/ wiki/Consistent_hashing)—a smarter mapping of keys to nodes, which is more resil- ient to changes in the cluster.

It’s obvious that the implementation can quickly become more involved, which is why we started simple and chose the global registration approach. Although it’s not particularly scalable, it’s a simple solution that works. But if you need better perfor- mance and scale, you’ll have to resort to a more complex approach.

### Rule of thumb for storing across network partitions

In reality, if you’re asking another process to store data, you should request a confirmation message so you know whether the data has been stored or something went wrong. This becomes increasingly important as you move to a less reliable communication medium (network) where all sorts of things can go wrong. When you expect a request to be used across nodes, you should usually implement it as a call.

### Always provide timeouts

The timeout provided to multicall is important. Without it, multicall, and in turn your store operation, would be blocked forever.

When doing distributed calls, you should usually specify a timeout. Note that this is no different from cross-process calls—when making a call to another process, you usually want to have a timeout as well, and GenServer recognizes this by providing a default 5-second timeout. Again, cross-node operations aren’t all that different from cross-process operations, and in many cases you have to consider a similar set of problems when developing a single-node system.

### Use calls for node-node communication

When communicating between nodes, use calls rather than casts.

### Deployment

You spent a lot of time building your to-do system, and it’s time to prepare it for production. There are various ways to start your system, but the basic idea is always the same. You have to compile your code as well as your dependencies. Then you start the BEAM instance and ensure that all compiled artifacts are in the load path. Finally, from within the BEAM instance, you need to start your OTP application together with its dependencies. Once the OTP application is started, you can consider your system to be running.

### Bypassing the shell when starting BEAM

When you invoke iex -S mix, all the steps just mentioned are taken to start the system. When running in production, you may want to avoid implicitly starting the iex shell. elixir -S mix run --no-halt will do that for you.

Starting the system with elixir -S mix gets rid of the shell, but the output is still printed. You can get rid of the output by starting the system in detached mode. The OS process will be detached from the terminal, and there will be no console output (it’s redirected to /dev/null).

Starting a detached BEAM instance is as simple as providing a --detached flag to the elixir tool. It’s also useful to turn the BEAM instance into a node, so you can later interact with it and terminate it when needed:
elixir --detached --sname foo@localhost -S mix run --no-halt

### Connecting to another BEAM shell

A useful thing is that you can connect to a running BEAM instance and interact with it. It’s possible to establish a remote shell— something like a terminal shell session to the running BEAM instance. In particular, you can start another node and use it as a shell to the foo node. This can be done using the --remsh option:

iex --sname bar@localhost --remsh foo@localhost --hidden

Shell is running on the foo node.

To stop the running system (foo), you can use the :init.stop/0 function, which takes down the system in a graceful manner. It shuts down all running applications and then terminates the BEAM instance: init.stop.

The remote shell session is left hanging, and an attempt to run any other command will result in an error. At this point, you can close the shell.

### Elixir script to stop running nodes

```
if Node.connect(:foo@localhost) == true do
  :rpc.call(:foo@localhost, :init, :stop, [])
  IO.puts "Node terminated."
else
  IO.puts "Can't connect to a remote node."
end
```

You can store the code in the file stop_node.exs (the .exs extension is frequently used for Elixir-based scripts). Then you can run the script from the command line: elixir --sname terminator@localhost stop_node.exs

Running a script starts a separate BEAM instance and interprets the code in that instance. After the script code is executed, the host instance is terminated. Because the script instance needs to connect to a remote node (the one you want to termi- nate), you need to give it a name to turn the BEAM instance into a proper node.


### Mix.env has meaning only during compilation

You can use the mix environment to conditionally include code for development- or test-time convenience. For example, you can rely on the existence of the Mix.env variable to define different versions of a function. Here’s a simple sketch:

```
defmodule Todo.Database do
  case Mix.env do
    :dev ->
      def store(key, data) do ... end
    :test ->
      def store(key, data) do ... end
    _ ->
      def store(key, data) do ... end
  end
end

```
Notice how you branch on Mix.env on the module level, outside of any functions. This is a compile-time construct, and this code runs during compilation. It’s important to understand that Mix.env has meaning only during compilation. You should never rely on it at runtime.

###  Always compile code with prod environment for production

You should assume that your project isn’t completely optimized when compiled in the :dev environment. When running in production, you usually want to use another mix environment, and the prevalent convention is :prod.

MIX_ENV=prod elixir -S mix run --no-halt

This causes recompilation of the code and all dependencies. All .beam files are stored in the _build/prod folder, and mix ensures that the BEAM instance loads files from this folder.

### Protocol Consolidation

Protocols, described in chapter 4, are also important. To refresh your memory, proto- cols are Elixir’s way of implementing polymorphism. For example, you can iterate over all sorts of data structures, such as lists, maps, and streams, using the single Enum.each/2 function. This function can iterate any structure that implements the Enumerable protocol. Internally, Enum.each/2 makes a polymorphic dispatch to the Enumerable protocol, and this dispatch is resolved at runtime. I won’t get into the details, but you should be aware that dispatch resolving is by default not as efficient as it could be, mostly in order to support development-time convenience.

To make the protocol dispatch as efficient as possible, you need to consolidate pro- tocols. Consolidation analyzes the current state of the project and generates the most efficient dispatching code for each protocol used in the project (and its dependen- cies). Performing a consolidation is as simple as running mix compile.protocols. This is usually needed only when preparing to run in production, so you can also use the :prod mix environment:

MIX_ENV=prod mix compile.protocols (Consolidated protocols written to _build/prod/consolidated)

As the result of the consolidation, you have optimized .beam files in the _build/prod/ consolidated folder. You now need to instruct Elixir to use this folder when looking for binaries:

MIX_ENV=prod elixir -pa _build/prod/consolidated -S mix run --no-halt

And that’s all it takes to optimize protocol dispatch.

### Tip: Always compile in prod env and consolidate protocols

It should be obvious from the discussion that the default compile code (in :dev mode) isn’t as optimal as it could be. This allows for better develop- ment convenience, but it makes the code perform less efficiently. When you decide to measure how your system behaves under a heavier load, you should always consolidate protocols and compile everything in the :prod environ- ment. Measuring a default :dev and nonconsolidated code may give you false indications about bottlenecks, and you may spend energy and time optimiz- ing code that isn’t problematic when it’s consolidated and compiled in the :prod environment.

### Downside of using mix and elixir to deploy and run prod system

At this point, you’re done with the basics of starting the system with mix and elixir. This process was mostly simple, and it fits nicely into your development flow.

There are some serious downsides, though. First, to start the project with mix, you need to compile it, which means the system source code must reside on the host machine. You need to fetch all dependencies and compile them as well. Consequently, you’ll need to install all tools required for compilation on the target host machine. This includes Erlang and Elixir, hex and possibly rebar, and any other third-party tools that you integrate in your mix workflow.

This means you’ll need to pollute the target host machine with compile-time tools. Moreover, if you’re running multiple systems on the same machine, it can become increasingly difficult to reconcile different versions of support tools that are needed for different systems. Luckily, there is a way out, in the form of OTP releases.

### OTP Releases over using mix/elixir

An OTP release is a standalone, compiled, runnable system that consists of the mini- mum set of OTP applications needed by the system. An OTP release can optionally include the minimum set of Erlang runtime binaries, which makes the release com- pletely self-sufficient. A release doesn’t contain artifacts, such as source code, docu- mentation files, or tests.

This approach provides all sort of benefits. First, you can build the system on your development machine or the build server and ship only binary artifacts. Furthermore, the host machine doesn’t need to have any tools installed. If you embed the minimum Erlang runtime into the release, you don’t even need Elixir and Erlang installed on the production server. Whatever is required to run the system will be the part of your release package. Finally, releases pave the way for systematic online system upgrades (and downgrades), known in Erlang as release handling.

Conceptually, releases seem simple. You need to compile your main OTP applica- tion and all of its dependencies and then include all the binaries in the release, together with the Erlang runtime.

### Building a release with exrm

As it is, exrm is currently the best option for deployments. However, it now seems exrm is replaced by Distillery.

exrm gives us the mix release command.

Also note that exrm performs protocol consolidation automati- cally, so you don’t need to worry about this step.

MIX_ENV=prod mix compile --no-debug-info
MIX_ENV=prod mix release

After mix release is done, your release resides in the rel/todo subfolder.

### Using a release

The main tool used to interact with a release is the shell script that resides in rel/ todo/bin/todo. You can use it to perform all kinds of tasks, such as these:
* Starting the system and iex shell in the foreground
* Starting the system as a background process
* Stopping the running system
* Attaching a remote shell to the running system

The simplest way to verify that the release works is to start the system in the fore- ground together with the iex shell:

rel/todo/bin/todo console

I want to stress that the release is no longer dependent on your system’s Erlang and Elixir. It’s fully standalone: you can copy the contents of the rel subfolder to another machine where Elixir and Erlang aren’t installed, and it will still work. Of course, because the release contains Erlang runtime binaries, the target machine has to be powered by the same OS and architecture.

To start the system as a background process, you can use the start argument:

rel/todo/bin/todo start

### Removing Erlang runtime from release

But embedding the Erlang runtime also ties the release to the particular OS ver- sion and architecture. If this doesn’t suit your needs, you can remove the runtime from the release. Currently, the simplest way to do this is to create a file called todo/ rel/relx.config and place the {include_erts, false}. option in it (note the ending dot character). Then you can regenerate the release, which now won’t contain the Erlang runtime. Nothing else needs to be changed, and you can use the release exactly as before. The release will rely on the existence of the appropriate Erlang run- time, which must be available in the path.