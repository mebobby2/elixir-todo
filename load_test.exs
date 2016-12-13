# Before starting, run:
#   MIX_ENV=prod mix compile.protocols
#
# Then, to start the test:
#   MIX_ENV=prod elixir  -pa _build/prod/consolidated/  -S mix run load_test.exs

:ok = :mnesia.wait_for_tables([:todo_lists], 1000)
{:atomic, :ok} = :mnesia.clear_table(:todo_lists)

:os.cmd('wrk -t4 -c100 -d120s --timeout 2000 -s wrk.lua "http://localhost:5454"') |> IO.puts

Application.stop(:mnesia)
File.rm_rf("./Mnesia.nonode@nohost")

#This runs a benchmark for 120 seconds, using 4 threads, and keeping 100 HTTP connections open.




## Results Before Optimisations

# Running 2m test @ http://localhost:5454
#   4 threads and 100 connections
#   Thread Stats   Avg      Stdev     Max   +/- Stdev
#     Latency    29.40ms   22.47ms 361.19ms   89.14%
#     Req/Sec   697.60    307.07     1.44k    64.14%
#   71345 requests in 2.00m, 7.85MB read
#   Socket errors: connect 0, read 66358, write 113, timeout 0
#   Non-2xx or 3xx responses: 66171
# Requests/sec:    594.01
# Transfer/sec:     66.95KB

# Those 66171 error responses are these:
#=ERROR REPORT==== 26-Nov-2016::13:08:18 ===
#Ranch listener 'Elixir.Todo.Web.HTTP' had connection process started with cowboy_protocol:start_link/4 at <0.17280.0> exit with reason: {{noproc,{'Elixir.GenServer',call,[todo_cache,{server_process,<<"list_311">>},5000]}},{'Elixir.Todo.Web',call,[#{'__struct__' => 'Elixir.Plug.Conn',adapter => {'Elixir.Plug.Adapters.Cowboy.Conn',{http_req,#Port<0.22411>,ranch_tcp,keepalive,<0.17280.0>,<<"GET">>,'HTTP/1.1',{{127,0,0,1},52189},<<"localhost">>,undefined,5454,<<"/entries">>,undefined,<<"list=list_311&date=20131207">>,undefined,[],[{<<"host">>,<<"localhost:5454">>}],[],undefined,[],waiting,<<>>,undefined,false,waiting,[],<<>>,undefined}},assigns => #{},before_send => [],body_params => #{'__struct__' => 'Elixir.Plug.Conn.Unfetched',aspect => body_params},cookies => #{'__struct__' => 'Elixir.Plug.Conn.Unfetched',aspect => cookies},halted => false,host => <<"localhost">>,method => <<"GET">>,owner => <0.17280.0>,params => #{'__struct__' => 'Elixir.Plug.Conn.Unfetched',aspect => params},path_info => [<<"entries">>],peer => {{127,0,0,1},52189},port => 5454,private => #{},query_params => #{'__struct__' => 'Elixir.Plug.Conn.Unfetched',aspect => query_params},query_string => <<"list=list_311&date=20131207">>,remote_ip => {127,0,0,1},req_cookies => #{'__struct__' => 'Elixir.Plug.Conn.Unfetched',aspect => cookies},req_headers => [{<<"host">>,<<"localhost:5454">>}],request_path => <<"/entries">>,resp_body => nil,resp_cookies => #{},resp_headers => [{<<"cache-control">>,<<"max-age=0, private, must-revalidate">>}],scheme => http,script_name => [],secret_key_base => nil,state => unset,status => nil},nil]}}

# Not entirely sure what those errors are but it seems like they are dropped TCP connections.

# Somes though, it runs without dropped connections. So its safe to assume the errors are not caused by errors
# in the code, but due to performance issues of the server.
# Running 2m test @ http://localhost:5454
#   4 threads and 100 connections
#   Thread Stats   Avg      Stdev     Max   +/- Stdev
#     Latency   144.17ms  361.47ms   5.04s    93.74%
#     Req/Sec   560.68    534.10     2.58k    83.96%
#   264072 requests in 2.00m, 78.31MB read
#   Socket errors: connect 0, read 8, write 0, timeout 0
#   Non-2xx or 3xx responses: 8
# Requests/sec:   2199.54
# Transfer/sec:    667.90KB

## Results After Optimisations

# Running 2m test @ http://localhost:5454
#   4 threads and 100 connections
#   Thread Stats   Avg      Stdev     Max   +/- Stdev
#     Latency    13.55ms   17.70ms 275.53ms   88.18%
#     Req/Sec     2.85k   727.29     4.74k    68.04%
#   1357850 requests in 2.00m, 338.71MB read
# Requests/sec:  11306.99
# Transfer/sec:      2.82MB


