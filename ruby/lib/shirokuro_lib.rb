# -------------------------------------------------
# GameClass
# -------------------------------------------------
class Game
  attr_accessor :board
  
	#
	# ボードの生成と初期石配置
  # 引数を渡された場合、board情報に基づいたインスタンスを生成
  def initialize(brd=nil)
    @board = Board.new
    unless brd
      @board.placing(3,3,Stone.new(:w))
      @board.placing(4,4,Stone.new(:w))
      @board.placing(3,4,Stone.new(:b))
      @board.placing(4,3,Stone.new(:b))
    else
      0.upto(7) do |y|
        0.upto(7) do |x|
          if brd[y][x]
            @board.placing(x, y, Stone.new(brd[y][x].to_sym))
          end
        end
      end
    end
  end

  #
  # 石配置
  #   - 石を配置可能か
  #   - 石の配置 & ひっくり返す
  def put(clr, x, y)
    #
    where = where_reversible(x,y,clr)
    return false if where == []
    #$log.debug("#{x},#{y} is reversible")
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
    #$log.debug("#{x},#{y} is empty")
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
    #$log.debug "x:#{x},y:#{y},clr:#{clr},h:#{h},v:#{v}"
    target = []
    x+=h; y+=v
    until x<0 or x>7 or y<0 or y>7 # 盤外に出たら終了
      #$log.debug("  looping x:#{x}, y:#{y}")
      break unless @board.stone(x,y)
      if target.uniq.size <= 2 # 近い2色分押さえとけばOK
        target << @board.stone(x,y).clr
      else
        break
      end
      x+=h; y+=v # 対象の移動
    end
    #$log.debug "target.uniq == #{target.uniq}"
    #$log.debug "[Stone.new] == #{[Stone.new(clr).other.clr, clr]}"
    #$log.debug "#{target.uniq == [Stone.new(clr).other.clr, clr]}"
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
    #$log.debug("action: #{act}")
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

  #
  #
  def where_puttable(clr)
    places = []
    0.upto 7 do |x|
      0.upto 7 do |y|
        if where_reversible(x,y,clr.to_sym).size > 0
          places << {x: x, y: y}
        end
      end
    end
    return places
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
    #$log.debug "[BOARD]"
    @self.map do |row|
      _row = row.map{|s| s ? s.to_s : "X"}.join
      #$log.debug _row
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


