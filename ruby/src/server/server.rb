#!/Users/nakaso/.rbenv/shims/ruby

# -------------------------------------------------
# library/module
# -------------------------------------------------
require 'em-websocket'
require 'optparse'
require 'json'

# -------------------------------------------------
# How to Use
# -------------------------------------------------
# execute:
#   ruby othello_serv.rb
#
# require:
#   gem install em-websocket


# -------------------------------------------------
# Structure
# -------------------------------------------------
# [Server]
#
# [Match]
#
# [Player]
#
# [Game]
#
# [Board]
#
# [Stone]
#


# -------------------------------------------------
# Const
# -------------------------------------------------
DEFAULT_HOST = '0.0.0.0'
DEFAULT_PORT = 8088
TIMEOUT = 1
# action type
#   role:     role送信指示[:player/:monitor]
#   wait:     次回指示待ち指示
#   attack:   石配置指示
#   deffence: 石配置待ち指示
#   finish:   対戦終了通知
#   monitor:  観戦者向け通信
PLAYER_ACTION = [:role, :wait, :attack, :deffence, :finish, :monitor]


# -------------------------------------------------
# Server
# -------------------------------------------------
class Server
  def initialize(host, port)
    $log.info "started on ws://#{host}:#{port}"
    Match.new

    EM::WebSocket.start({:host => host, :port => port}) do |session|

      # session確立時
      session.onopen do
        Player.new(session)
      end

      # session切断時
      session.onclose do
        # TODO: そのうち対応
      end
    
      # error検知時
      session.onerror do
        # TODO: そのうち対応
      end
    
      # message受信時
      session.onmessage do |msg|
        $log.info "===================================="
        $log.info "<<<< #{Player.who(session).id}: #{msg}"
        begin
          msg = JSON.load(msg)
        rescue
          $log.error("message is not JSON")
          raise ArgumentError
        end

        if match = Match.which(Player.who(session))
          match.recv(Player.who(session), msg)
        else
          Match.matching(Player.who(session), msg)
        end
      end
      
    end
  end
end


# -------------------------------------------------
# MatchClass
# -------------------------------------------------
class Match
  @@list = []
  attr_accessor :p1, :p2, :monitor, :game, :timer

  #
  #
  def initialize
    @@list << self
  end

  #
  #
  def self.matching(plyr, msg)
    case msg['role']
    when 'player'
      if @@list[-1].p1 == nil
        @@list[-1].p1 = plyr
        @@list[-1].p1.name = msg['name']
        plyr.operation :wait
      else
        @@list[-1].p2 = plyr
        @@list[-1].p2.name = msg['name']
        @@list[-1].start
        self.new()
      end

    when 'monitor'
      @@list[-1].monitor = plyr
      plyr.operation :wait

    else
      $log.error("role:#{msg['role']} is not acceptable")
      raise ArgumentError

    end
  end

  #
  # 所属matchの検索
  def self.which(plyr)
    return @@list.find{|m| m.p1 == plyr or m.p2 == plyr}
  end

  #
  # 対戦開始
  def start
    $log.info "GameMatching: #{@p1.id} vs #{@p2.id}"
    # 先行をRandomで決定
    pre = [*1..2].sample
    post = pre == 1 ? 2 : 1
    # Gameの生成, 関連付け
    @game = Game.new
    # Player情報の更新
    eval("@p#{pre}.is_attacker = true")
    eval("@p#{pre}.clr = :b")
    eval("@p#{post}.is_attacker = false")
    eval("@p#{post}.clr = :w")
    # Timerの生成, 関連付け
    unless $option[:debug]
      @timer = Timer.new
      @timer.watch attacker
    end
    # actionの通知
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    if @monitor
      @monitor.clr  = "#{@p1.name}'s color: #{@p1.clr}"
      @monitor.clr += " / #{@p2.name}'s color: #{@p2.clr}"
      @monitor.operation(:monitor, @game.board.to_a)
    end
  end

  #
  # コマを置かれた場合に起動
  #   - attackerからの信号でなければ無視
  #   - コマ配置
  #   - 次のアクション指示[:change, :pass, :finish]
  def recv(plyr, msg)
    #
    unless plyr.is_attacker
      plyr.operation :deffence, @game.board
      return
    end
    #
    unless @game.put(plyr.clr, msg['x'], msg['y'])
      finish(plyr)
      return
    end
    #
    eval "#{@game.next_action(Stone.new(plyr.clr).other)}"
  end

  #
  #
  def change
    if @p1.is_attacker
      @p1.is_attacker = false
      @p2.is_attacker = true
    else
      @p1.is_attacker = true
      @p2.is_attacker = false
    end
    @timer.watch attacker unless $option[:debug]
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    @monitor.operation(:monitor, @game.board.to_a) if @monitor
  end

  #
  #
  def pass
    @timer.watch attacker unless $option[:debug]
    deffender.operation(:deffence, @game.board.to_a)
    attacker.operation(:attack, @game.board.to_a)
    @monitor.operation(:monitor, @game.board.to_a) if @monitor
  end

  #
  # 対戦終了
  #   - 反則による終了(=カウント不要)
  #     - 攻撃時間を超過した場合
  #     - 配置不可な場所に配置しようとした場合
  #   - 配置可能場所が無くなって終了(=カウント要)
  #     - 盤上が全て埋まっている場合
  #     - 両者ともパスになる場合
  #     - 盤面が片方の色になる場合
  def finish(loser=nil)

    @timer.cancel
    brd = @game.board.to_a

    if loser
      $log.info("finish winer=#{other_plyr(loser).name}, loser=#{loser.name}")
      # 反則終了
      loser.operation(:finish, brd, :lose)
      other_plyr(loser).operation(:finish, brd, :win)

    else
      # 配置可能場所枯渇
      attacker_count = @game.board.count(attacker.clr)
      deffender_count = @game.board.count(deffender.clr)
      $log.info("#{attacker.name} has #{attacker_count}, #{deffender.name} has #{deffender_count}")
      if attacker_count > deffender_count
        attacker.operation(:finish, brd, :win)
        deffender.operation(:finish, brd, :lose)
        @monitor.operation(:finish, brd, "winner is #{attacker.name}") if @monitor
        
      elsif attacker_count < deffender_count
        attacker.operation(:finish, brd, :lose)
        deffender.operation(:finish, brd, :win)
        @monitor.operation(:finish, brd, "winner is #{deffender.name}") if @monitor

      else
        attacker.operation(:finish, brd, :draw)
        deffender.operation(:finish, brd, :draw)
        @monitor.operation(:finish, brd, :draw) if @monitor

      end
      $log.info("finish loser=#{loser.name}")
    end

    # TODO: Match.@@listから削除: oncloseからも呼べるようなめそっどにする

  end

  #
  #
  def attacker
    return attacker = @p1.is_attacker ? @p1 : @p2
  end

  #
  #
  def deffender
    return deffender = @p1.is_attacker ? @p2 : @p1
  end

  #
  #
  def other_plyr(plyr)
    return other = plyr == @p1 ? @p2 : @p1
  end

end


# -------------------------------------------------
# PlayerClass
# -------------------------------------------------
class Player
  @@entry = {}
  attr_accessor :session, :name, :clr, :is_attacker

  #
  #
  def initialize(session)
    @session = session
    @@entry[session] = self

    operation(:role)
  end

  #
  def operation(act, brd=nil, rslt=nil)
    $log.info ">>>> #{Player.who(@session).id}: #{act}"
    raise NameError unless PLAYER_ACTION.include? act
    @session.send({action: act, board: brd.to_a, result: rslt, color: @clr}.to_json)
  end

  #
  # sessionからPlayerインスタンスを引いて返却
  def self.who(session); @@entry[session]; end

  #
  #
  def is_attacker?; @is_attacker; end

  #
  # PlayerID
  #   object_idそのままだと長いので下6桁に
  def id; self.object_id.to_s[-6..-1]; end

end


# -------------------------------------------------
# TimerClass
# -------------------------------------------------
class Timer
  attr_accessor :thread, :should_fire

  #
  #
  def initialize
    @should_fire = true
  end

  #
  #
  def watch(target)
    if @thread
      kill
    end

    @thread = Thread.fork do
      sleep TIMEOUT
      fire(target) if @should_fire
    end
  end

  #
  #
  def cancel
    @should_fire = false
  end

  #
  #
  def kill
    if @thread
      @thread.kill
      while @thread.alive?; end
      @thread = nil
    end
  end

  #
  #
  def fire(target)
    $log.info("#{TIMEOUT}sec timeout: loser is #{target.name}")
    Match.which(target).finish(target)
  end

end


# -------------------------------------------------
# GameClass
# -------------------------------------------------
class Game
  attr_accessor :board
  
	#
	# ボードの生成と初期石配置
  def initialize
    @board = Board.new
    @board.placing(3,3,Stone.new(:w))
    @board.placing(4,4,Stone.new(:w))
    @board.placing(3,4,Stone.new(:b))
    @board.placing(4,3,Stone.new(:b))
  end

  #
  # 石配置
  #   - 石を配置可能か
  #   - 石の配置 & ひっくり返す
  def put(clr, x, y)
    #
    where = where_reversible(x,y,clr)
    return false if where == []
    $log.debug("#{x},#{y} is reversible")
    #
    @board.placing(x,y,Stone.new(clr))
    reverse(x,y,where)
    @board.screen
    return true
  end

  #
  # コマを配置可能か確認
  #   - 空いてるか
  #   - ひっくり返せるか
  def where_reversible(x, y, clr)
    #
    return [] if @board.stone(x,y)
    $log.debug("#{x},#{y} is empty")
    #
    where = []
    where << {x: -1, y:  1} if reversible?(x,y,clr,-1, 1)
    where << {x: -1, y:  0} if reversible?(x,y,clr,-1, 0)
    where << {x: -1, y: -1} if reversible?(x,y,clr,-1,-1)
    where << {x:  0, y:  1} if reversible?(x,y,clr, 0, 1)
    where << {x:  0, y: -1} if reversible?(x,y,clr, 0,-1)
    where << {x:  1, y:  1} if reversible?(x,y,clr, 1, 1)
    where << {x:  1, y:  0} if reversible?(x,y,clr, 1, 0)
    where << {x:  1, y: -1} if reversible?(x,y,clr, 1,-1)
    where
  end

  #
  # 指定された方向でひっくり返すことができるか確認
  # 指定方向に石を確認し、異色が出てその先に同色が出たらOK
  #   h .. 水平方向
  #   v .. 垂直方向
  def reversible?(x, y, clr, h, v)
    $log.debug "x:#{x},y:#{y},clr:#{clr},h:#{h},v:#{v}"
    target = []
    x+=h; y+=v
    until x<0 or x>7 or y<0 or y>7 # 盤外に出たら終了
      $log.debug("  looping x:#{x}, y:#{y}")
      break unless @board.stone(x,y)
      if target.uniq.size <= 2 # 近い2色分押さえとけばOK
        target << @board.stone(x,y).clr
      else
        break
      end
      x+=h; y+=v # 対象の移動
    end
    $log.debug "target.uniq == #{target.uniq}"
    $log.debug "[Stone.new] == #{[Stone.new(clr).other.clr, clr]}"
    $log.debug "#{target.uniq == [Stone.new(clr).other.clr, clr]}"
    return target.uniq == [Stone.new(clr).other.clr, clr]
  end

  #
  #
  def reverse(x, y, where)
    where.each do | w |
      until @board.stone(x, y).eql? @board.stone(x+w[:x], y+w[:y])
        @board.stone(x+w[:x], y+w[:y]).reverse
        w[:x] += w[:x]<=>0
        w[:y] += w[:y]<=>0
      end
    end
  end

  #
  # 次にプレイヤーに与えるActionを決定する
  #   :change
  #     => 与えられた石(置き終わった人と逆の人の石)を置ける場合
  #   :pass 
  #     => 与えられた石(置き終わった人と逆の人の石)が置けない 
  #        && 置き終わった人の石が再度置ける場合
  #   :finish
  #     => 相互に打つことができない場合
  #        - 盤上が全て埋まっている場合
  #        - 両者ともパスになる場合
  #        - 盤面が片方の色になる場合
  def next_action(stone)
    if can_put? stone
      act = :change
    else
      if can_put? stone.other
        act = :pass
      else
        act = :finish
      end
    end
    $log.debug("action: #{act}")
    return act
  end

  #
  # Board上に指定された石色を置くことが可能か
  def can_put?(stone)
    0.upto 7 do |x|
      0.upto 7 do |y|
        return true if where_reversible(x,y,stone.clr).size > 0
      end
    end
    false
  end

end


# -------------------------------------------------
# BoardClass
# -------------------------------------------------
class Board
  attr_accessor :self

  #
  # 
  def initialize
    @self = Array.new(8).map{Array.new(8)}
  end

  #
  # 石の配置
  def placing(x, y, s); @self[y][x] = s; end

  #
  # 指定位置のStoneインスタンスを返却
  def stone(x, y); @self[y][x]; end

  #
  # 盤上が全て埋まっているか
  def filled?; return !(@self.flatten.include?(nil)); end

  #
  # Board情報を配列で返却(JSON変換用)
  def to_a; @self; end

  #
  # 盤上情報を文字列に変更
  def to_s; "#{@self}"; end
  alias inspect to_s

  #
  # 盤上情報をCLIに出力
  def screen
    $log.debug "[BOARD]"
    @self.map do |row|
      _row = row.map{|s| s ? s.to_s : "X"}.join
      $log.debug _row
    end
  end

  #
  #
  def count(clr)
    return @self.flatten.join('').count("#{clr}")
  end

end


# -------------------------------------------------
# StoneClass
# -------------------------------------------------
class Stone
  attr_accessor :clr
  
  #
  #
  def initialize(clr); @clr = clr; end
  
  #
  #
  def reverse; @clr = @clr==:w ? :b : :w; end

  #
  #
  def eql? other; @clr.eql? other.clr; end

  #
  #
  def other; return Stone.new clr = @clr==:w ? :b : :w; end

  #
  # 石色を文字列で返却
  def to_s; "#{@clr}"; end
  alias inspect to_s

end


# -------------------------------------------------
# main
# -------------------------------------------------
# option
$option = {debug: false}
OptionParser.new do |opt|
  opt.on('--host=[VALUE]', "[str] host name (default: #{DEFAULT_HOST})"){|v| $option[:host] = v}
  opt.on('--port=[VALUE]', "[int] port number (default: #{DEFAULT_PORT})"){|v| $option[:port] = v}
  opt.on('--debug',        '[ - ] logging debug log'){|v| $option[:debug] = v}
  opt.parse!(ARGV)
end

# logger
$log = Object.new
def $log.info(msg);  puts "[INFO ] #{msg}"; end
def $log.error(msg); puts "[ERROR] #{msg}"; end
if $option[:debug]
  def $log.debug(msg); puts "[DEBUG] #{msg}"; end
else
  def $log.debug(msg); end
end
$log.debug "MODE DEBUG"

# start up server
host = $option[:host] ? $option[:host] : DEFAULT_HOST
port = $option[:port] ? $option[:port] : DEFAULT_PORT
Server.new(host, port)
