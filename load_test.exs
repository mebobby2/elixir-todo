# Setup:
#   brew install wrk
#
# Before starting, run:
#   MIX_ENV=prod mix compile.protocols
#
# Then, to start the test:
#   MIX_ENV=prod elixir  -pa _build/prod/consolidated/  -S mix run load_test.exs
#
# Then, wait 120s (or how long the test runs for) to see the results

File.rm_rf("./persist")
File.mkdir_p("./persist")
:os.cmd('wrk -t4 -c100 -d120s --timeout 2000 -s wrk.lua "http://localhost:5454"') |> IO.puts

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