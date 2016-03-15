#!/Users/nakaso/.rbenv/shims/ruby

## -------------------------------------------------
## library/module
## -------------------------------------------------
require 'websocket-client-simple'
require 'json'

ws = WebSocket::Client::Simple.connect 'http://0.0.0.0:8088'

ws.on :open do
  puts "on_open"
end

ws.on :close do |e|
  puts "on_open"
  exit
end

ws.on :message do |msg|
  begin
    msg = JSON.load(msg.data.to_s)
  rescue => e
    puts e.backtrace
    return
  end
  puts "action: #{msg['action']}"
  if msg['action']=='role'
    puts "send"
    ws.send $role.to_json
    puts "sent"
  end

  if msg['action']=='attack'
    if msg['color']=='b'
      puts "send!"
      ws.send $debug_stons_b.shift.to_json
    else
      puts "send!"
      ws.send $debug_stons_w.shift.to_json
    end
    puts "sent"
  end
end

$role = {role: :player, name: Time.new}

$debug_stons_b = [
  {x: 3, y: 2},
  {x: 1, y: 2},
  {x: 3, y: 0},
  {x: 5, y: 1},
  {x: 5, y: 0},
  {x: 5, y: 5},
  {x: 5, y: 3},
  {x: 5, y: 2},
  {x: 6, y: 3},
  {x: 6, y: 2},
  {x: 6, y: 4},
  {x: 6, y: 1},
  {x: 6, y: 5},
  {x: 4, y: 5},
  {x: 1, y: 3},
  {x: 2, y: 4},
  {x: 7, y: 0},
  {x: 7, y: 3},
  {x: 3, y: 5},
  {x: 7, y: 5},
  {x: 7, y: 6},
  {x: 7, y: 7},
  {x: 5, y: 7},
  {x: 2, y: 5},
  {x: 1, y: 5},
  {x: 0, y: 2},
  {x: 4, y: 7},
  {x: 2, y: 7},
  {x: 1, y: 1},
  {x: 0, y: 5},
  {x: 0, y: 6},
  {x: 0, y: 0},
]

$debug_stons_w = [
  {x: 2, y: 2},
  {x: 3, y: 1},
  {x: 4, y: 2},
  {x: 4, y: 1},
  {x: 4, y: 0},
  {x: 2, y: 0},
  {x: 6, y: 0},
  {x: 5, y: 4},
  {x: 7, y: 4},
  {x: 2, y: 1},
  {x: 5, y: 6},
  {x: 0, y: 3},
  {x: 7, y: 1},
  {x: 2, y: 3},
  {x: 6, y: 6},
  {x: 1, y: 4},
  {x: 7, y: 2},
  {x: 3, y: 6},
  {x: 6, y: 7},
  {x: 4, y: 6},
  {x: 2, y: 6},
  {x: 0, y: 4},
  {x: 0, y: 1},
  {x: 3, y: 7},
  {x: 1, y: 6},
  {x: 1, y: 0},
  {x: 0, y: 7},
  {x: 1, y: 7}
]

loop{}
