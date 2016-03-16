#!/Users/nakaso/.rbenv/shims/ruby

# -------------------------------------------------
# library/module
# -------------------------------------------------
require 'websocket-client-simple'
require 'json'


# -------------------------------------------------
# How to Use
# -------------------------------------------------
# require:
#   gem install websocket-client-simple

# -------------------------------------------------
# const
# -------------------------------------------------
SERV = 'ws://0.0.0.0:8088'
NAME = "nkmr"
ROLE = "player"
FILE = "./training/training.log"

# -------------------------------------------------
# logic
# -------------------------------------------------
def where_should_i_place(brd, clr)
  places = where_puttable(brd, clr)
  place = places.sample
  return place[:x], place[:y]
end

#
def where_puttable(brd, clr)
  places = []
  0.upto 7 do |x|
    0.upto 7 do |y|
      if where_reversible(brd,x,y,clr).size > 0
        places << {x: x, y: y}
      end
    end
  end
  return places
end

#
def where_reversible(brd,x,y,clr)
  #
  return [] if brd[y][x]
  #
  where = []
  where << {x: -1, y:  1} if reversible?(brd,x,y,clr,-1, 1)
  where << {x: -1, y:  0} if reversible?(brd,x,y,clr,-1, 0)
  where << {x: -1, y: -1} if reversible?(brd,x,y,clr,-1,-1)
  where << {x:  0, y:  1} if reversible?(brd,x,y,clr, 0, 1)
  where << {x:  0, y: -1} if reversible?(brd,x,y,clr, 0,-1)
  where << {x:  1, y:  1} if reversible?(brd,x,y,clr, 1, 1)
  where << {x:  1, y:  0} if reversible?(brd,x,y,clr, 1, 0)
  where << {x:  1, y: -1} if reversible?(brd,x,y,clr, 1,-1)
  where
end

#
def reversible?(brd, x, y, clr, h, v)
  target = []
  x+=h; y+=v
  until x<0 or x>7 or y<0 or y>7 # 盤外に出たら終了
    break unless brd[y][x]
    if target.uniq.size <= 2 # 近い2色分押さえとけばOK
      target << brd[y][x]
    else
      break
    end
    x+=h; y+=v # 対象の移動
  end
  if clr=='w'
    other = 'b'
  else
    other = 'w'
  end
  return target.uniq == [other, clr]
end

# -------------------------------------------------
# main
# -------------------------------------------------
  #
  # ATTENTION
  #   WSライブラリが別スレッドを使って動作するらしく
  #   例外発生時もスクリプトは落ちないので注意
  #
ws = WebSocket::Client::Simple.connect SERV

# 接続時
ws.on :open do
end

# 切断時
ws.on :close do |e|
  exit
end

# エラー発生時
ws.on :error do |e|
  exit
end

#
# メッセージ受信時
$rec = {record: [], winner: nil}
ws.on :message do |msg|
  begin
    msg = JSON.load(msg.data.to_s)
  rescue
    msg = {}
  end

  case msg['action']
  when 'role'
    ws.send({role: ROLE, name: NAME}.to_json)

  when 'attack'
    board = msg['board']
    color = msg['color']
    x, y = where_should_i_place(board, color)
    $rec[:record] << {
      no: $rec.size+1,
      board: board,
      move: {c: color, x: x, y: y}
    }
    ws.send({x: x, y: y}.to_json)

  when 'finish'
    p 0
    if msg['result'] == 'win'
      $rec[:winner] = msg['color']
      json = JSON.load open(FILE)
      json['data'] << $rec.to_json
      #p json
      open(FILE, 'w') do |file|
        JSON.dump(json, file)
      end
    end
    exit

  when 'wait', 'deffence'
    # do nothing
    
  end
end

loop{}
