# -------------------------------------------------
# library/module
# -------------------------------------------------
require 'websocket-client-simple'
require 'json'
require '../../lib/shirokuro_lib.rb'


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

# -------------------------------------------------
# logic
# -------------------------------------------------
def where_should_i_place(brd, clr)
  # 配置可能場所を取得
  g = Game.new(brd)
  places = g.where_puttable(clr)
  # 各マスの評価値を見て、一番点数の高いところを配列で取得
  candicate = []
  places.each do | place |
    candicate <<  place if candicate.empty?
    if RATE[candicate[0][:y]][candicate[0][:x]] < RATE[place[:y]][place[:x]]
      candicate.clear
      candicate << place
    elsif RATE[candicate[0][:y]][candicate[0][:x]] == RATE[place[:y]][place[:x]]
      candicate << place
    end
  end
  # 配列の中からランダムに一箇所を取得し、返却
  c = candicate.sample
  return c[:x], c[:y]
end

# 評価
# http://uguisu.skr.jp/othello/5-1.html
RATE = [
  [ 30,-12,  0, -1, -1,  0,-12, 30],
  [-12,-15, -3, -3, -3, -3,-15,-12],
  [  0, -3,  0, -1, -1,  0, -3,  0],
  [ -1, -3, -1, -1, -1, -1, -3, -1],
  [ -1, -3, -1, -1, -1, -1, -3, -1],
  [  0, -3,  0, -1, -1,  0, -3,  0],
  [-12,-15, -3, -3, -3, -3,-15,-12],
  [ 30,-12,  0, -1, -1,  0,-12, 30]
]


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
  puts "on_open"
end

# 切断時
ws.on :close do |e|
  puts "on_close"
  exit
end

# エラー発生時
ws.on :error do |e|
  puts "on_error #{e.backtrace}"
  exit
end

#
# メッセージ受信時
ws.on :message do |msg|
  begin
    msg = JSON.load(msg.data.to_s)
    puts "on_message"
  rescue
    return
  end

  case msg['action']
  when 'role'
    ws.send({role: ROLE, name: NAME}.to_json)

  when 'attack'
    board = msg['board']
    color = msg['color']
    x, y = where_should_i_place(board, color)
    ws.send({x: x, y: y}.to_json)

  when 'finish'
    puts "Match result is #{msg['result']}"
    exit

  when 'wait', 'deffence'
    # do nothing
    
  end
end

loop{}
