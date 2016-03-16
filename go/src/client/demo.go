package main

import (
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
)

func main() {
	port := 8080
	http.HandleFunc("/", index)
	http.HandleFunc("/think", othello)
	http.HandleFunc("/selftest", selftest)
	log.Printf("access http://0.0.0.0:%d/", port)
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}

func index(w http.ResponseWriter, _ *http.Request) {
	log.Printf("accessed /")
	fmt.Fprint(w, `
<!DOCTYPE html>
<HTML>
<META CHARSET="UTF-8">
<SCRIPT>
  function showStatus(msg) {
    var s = document.getElementById("status").innerHTML;
    document.getElementById("status").innerHTML = msg + "<br />" + s;
  }

  function str2mark(s) {
    if(s == null) {
      return "　";
    }
    if(s == "w") {
      return "○";
    }
    if(s == "b") {
      return "●";
    }
    return "？";
  }

  function showBoard(data) {
    var s = '';
    s += '<TABLE BORDER=1>';
    s += '<TR><TD> </TD>'
    for(var x=0; x<8; x++) {
      s += '<TD>' + x + '</TD>'
    }
    s += '</TR>';
    for(var y=0; y<8; y++) {
      s += "<TR><TD>" + y + "</TD>";
      for(var x=0; x<8; x++) {
        s += "<TD>" + str2mark(data[y][x]) + "</TD>";
      }
      s += '</TR>';
    }
    s += '</TABLE><BR />';
    document.getElementById("board").innerHTML = s;
  }

  function c2n(me, c){
    if(c == null) {
      return 0;
    }
    if(me == c) {
      return 2;
    }
    return 1;
  }

  function board2string(e) {
    var s = "";
    for(var y=0; y<8; y++) {
      for(var x=0; x<8; x++) {
        s += c2n(e.color, e.board[x][y]) + "";
      }
    }
    return s;
  }

  window.onload = function() {
    var uri = "ws://localhost:8088"
    sock = new WebSocket(uri);
    sock.onerror = function(evt) { showStatus("error"); }
    sock.onopen = function(evt)  { showStatus("onopen"); }
    sock.onclose = function(evt) { showStatus("disconnected."); }
    sock.onmessage = function(evt) {
      console.log(JSON.stringify(evt));
      var e = JSON.parse(evt.data);
      console.log(JSON.stringify(e));
      console.log(e);
      if(e.action == "role") {
        var name = Math.random().toString(36).slice(-8);
        document.getElementById("name").innerHTML = "my name: " + name;
        sock.send('{"role":"player","name":"' + name + '"}');
      } else if(e.action == "wait") {
        showStatus("waiting for another player...");
      } else if(e.action == "deffence") {
        showStatus("waiting..");
        showBoard(e.board);
      } else if(e.action == "attack") {
        console.log("ok attack");
        var s = document.createElement('SCRIPT');
        s.src = "./think?callback=websocksend&data=" + board2string(e);
        console.log(s.src);
        document.getElementById("request_sender").appendChild(s);
      } else if(e.action == "finish") {
        showStatus("finished. " + e.result);
      }
    }
  }

  function websocksend(res) {
    console.log(res);
    sock.send(res);
  }

  </SCRIPT>
  <BODY>
    <H2>Client for nakasonogitlab/othello</H2>
    <DIV ID="name"></DIV><BR />
    <DIV ID="board" STYLE="font-family: monospace;"></DIV><BR />
    <DIV ID="status"></DIV>
    <DIV ID="request_sender"></DIV>
  </BODY>
</HTML>
`)
}

func selftest(w http.ResponseWriter, _ *http.Request) {
	log.Printf("accessed /selftest")
	fmt.Fprint(w, `
<!DOCTYPE html>
<HTML>
  <SCRIPT>
  window.onload = function() {
  }
  </SCRIPT>
  <BODY>
    <H2>selftest</H2>
    <DIV ID="board"></DIV>
    <DIV ID="apicall"></DIV>
  </BODY>
</HTML>
`)
}

func othello(w http.ResponseWriter, r *http.Request) {
	result := `{}`
	defer func() {
		w.Header().Set("Content-Type", "application/json")
		fmt.Println(result)
		fmt.Fprint(w, result)
	}()
	r.ParseForm()
	callback := r.FormValue("callback")
	pos := think(strings.Split(r.FormValue("data"), ""))
	if callback != "" {
		x := strconv.Itoa(pos % 8)
		y := strconv.Itoa(pos / 8)
		result = callback + "(\"{\\\"x\\\":" + x
		result += ", \\\"y\\\":" + y + "}\");"
	}
}

func think(board []string) int {
	res := []int{}
	for i := 0; i < 8*8; i++ {
		if isCandidate(board, i) {
			res = append(res, 3)
		} else {
			n, _ := strconv.Atoi(board[i])
			res = append(res, n)
		}
	}
	return select_cell(res)
}

func isCandidate(board []string, target int) bool {
	if board[target] != "0" {
		return false
	}
	step := []int{-9, -8, -7, -1, 1, 7, 8, 9}
	r := regexp.MustCompile(`^1+2`)
	for v := 0; v < len(step); v++ {
		s := ""
		p := target
		for {
			p += step[v]
			if (0 > p) || (p > 63) {
				// ボードからはみ出していたらおしまい
				break
			}
			s += board[p]
			// sが条件をみたすかチェック,満たすなら文字列"1"を返す
			// 1=相手のコマが１つずつ続いたあとに
			// 2=自分のコマがあれば、
			// ここに自分のコマを置くと挟めることになる
			if r.MatchString(s) {
				return true
			}
		}
	}
	return false
}

func select_cell(board []int) int {
	//  重心を探して重心に一番近い置ける場所に置いているつもり
	//  少なくとも序盤は真ん中近くに置いていった方が良い気がする

	// まずx方向とy方向それぞれについてコマがいくつあるかを数える
	x_num := [8]int{0, 0, 0, 0, 0, 0, 0, 0}
	y_num := [8]int{0, 0, 0, 0, 0, 0, 0, 0}
	num := 0
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			if board[y*8+x] == 1 {
				x_num[x] += 1
				y_num[y] += 1
				num += 1
			}
		}
	}

	// 重心の場所を計算してみる
	x_ave := 0
	y_ave := 0
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			x_ave += x * x_num[x]
			y_ave += y * x_num[y]
		}
	}
	x_ave /= num
	y_ave /= num

	// 重心からの距離を計算する
	dist := [8 * 8]int{}
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			dist[y*8+x] = (x-x_ave)*(x-x_ave) + (y-y_ave)*(y-y_ave)
		}
	}

	// 一番重心に近い場所を探す
	no := -1
	for i := 0; i < len(board); i++ {
		if board[i] == 3 {
			if no == -1 {
				no = i
			} else {
				if dist[i] < dist[no] {
					no = i
				}
			}
		}
	}
	return no
}
