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
SERV = 'ws://localhost:8088'
NAME = "PECO"
INIT = {role: :player, name: NAME}


# -------------------------------------------------
# logic
# -------------------------------------------------
def where_should_i_place(board, color)
  #
  # ここの中を考えてオセロAIを作りましょう！
  #
  x = 3
  y = 2
  return x, y
end


# -------------------------------------------------
# main
# -------------------------------------------------
  #
  # ATTENTION
  #   WSライブラリが別スレッドを使って動作するらしく
  #   例外発生時もスクリプトは落ちないので注意
  #
ws = WebSocket::Client::Simple.connect SERV do |ws|

  #
  # 接続時に呼ばれる
  ws.on :open do
    puts "on_open"
  end
  
  #
  # 切断時に呼ばれる
  ws.on :close do |e|
    puts "on_close"
    exit
  end
  
  #
  # エラー発生時に呼ばれる
  ws.on :error do |e|
    puts "on_error"
    exit
  end

  #
  # メッセージ受信時
  ws.on :message do |msg|
    msg = JSON.load(msg.data.to_s)
    puts "on_message: #{msg}"
  
    case msg['action']
    when 'role'
      #
      # 最初に参加形態[player/monitor]を聞かれるの
      # AIの場合は"role":"player"とリクエストを送る
      # TODO: 同時に名前も送信するため、定位数の値を変更すること。
      ws.send INIT.to_json
  
    when 'wait'
      #
      # 対戦者の接続を待つ
      # do nothing
  
    when 'attack'
      #
      # msg['board']で現在の盤上の状態がJSON2次元配列で与えられる
      # msg['color']であなたが配置する石の色が与えられる
      board = msg['board']
      color = msg['color']
      #
      # 上記情報を元に、次の配置先を決定する
      x, y = where_should_i_place(board, color)
      #
      # 決定した配置先をサーバに通知する
      ws.send({x: x, y: y}.to_json)
  
    when 'deffence'
      #
      # 対戦相手が石を配置するのを待つ
      # do nothing
      
    when 'finish'
      #
      # 勝敗が送信されてくる
      puts "Match result is #{msg['result']}"
      exit
  
    end
  
  end
end


