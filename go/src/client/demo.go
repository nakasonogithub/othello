package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func main() {
	port := 8080
	http.HandleFunc("/", Index)
	http.HandleFunc("/think", Othello)
	http.HandleFunc("/selftest", selftest)
	log.Printf("access http://0.0.0.0:%d/", port)
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}

func Index(w http.ResponseWriter, _ *http.Request) {
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
    if(s == null) { return " "; }
    if(s == "w") { return "○"; }
    if(s == "b") { return "●"; }
    return "?";
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
    if(c == null) { return 0; }
    if(me == c) { return 2; }
    return 1;
  }

  function board2string(e) {
    var s = "";
    for(var y=0; y<8; y++) {
      for(var x=0; x<8; x++) {
        s += c2n(e.color, e.board[y][x]) + "";
      }
    }
    return s;
  }

  window.onload = function() {
    var uri = "ws://localhost:8088";
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
        showStatus("deffence, waiting for attack...  my color is " + e.color);
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

func Othello(w http.ResponseWriter, r *http.Request) {
	result := `{}`
	defer func() {
		w.Header().Set("Content-Type", "application/json")
		fmt.Println(result)
		fmt.Fprint(w, result)
	}()
	r.ParseForm()
	callback := r.FormValue("callback")
	x, y := Think(strings.Split(r.FormValue("data"), ""))
	if callback != "" {
		result = callback + "(\"{\\\"x\\\":" + strconv.Itoa(x)
		result += ", \\\"y\\\":" + strconv.Itoa(y) + "}\");"
	}
}

func Think(board []string) (int, int) {
	var tmp []int
        var turn_no int
	for i := 0; i<8*8; i++ {
		if board[i] != "0" {
			turn_no++
		}
	}
	for i := 0; i < 8*8; i++ {
		if IsCandidate(board, i) {
			tmp = append(tmp, i)
		}
	}
	if int(len(tmp)) == 0 {
		return -1, -1
	}
	w := []int{100,  2, 30,  5,  5, 30,  5, 100,
                     2,  2,  5,  3,  3,  5,  2,   2,
                    30,  2, 30, 10, 10, 30,  2,  30,
                     5,  2, 10,  0,  0, 10,  2,   5,
                     5,  2, 10,  0,  0, 10,  2,   5,
                    30,  2, 30, 10, 10, 30,  2,  30,
                     2,  2,  5,  3,  3,  5,  2,   2,
	           100,  2, 30, 10, 10, 30,  5, 100}
        var cans []int
        for _, can := range tmp {
		for i :=0; i<w[can]; i++ {
			cans = append(cans, can)
		}
	}
	fmt.Println(cans)
	var n int
	n = int(time.Now().UnixNano() % int64(len(cans)))
	return cans[n] % 8, cans[n] / 8
}

func IsCandidate(board []string, pos int) bool {
	if board[pos] != "0" {
		return false
	}
	for _, step := range []int{-9, -8, -7, -1, 1, 7, 8, 9} {
		found := false
		p := pos
		for {
			p += step
			x, y := p%8, p/8
			if x < 0 || 8 <= x || y < 0 || 8 <= y {
				break
			}
			if found {
				if board[p] == "2" {
					return true
				}
				if board[p] != "1" {
					break
				}
			} else {
				if board[p] == "1" {
					found = true
				} else {
					break
				}
			}
		}
	}
	return false
}

