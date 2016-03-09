// --------------------------------------------------
// WebSocket
// --------------------------------------------------
var session;

//
//
function connect(serv){
  session = new WebSocket(serv);

  //
  session.onopen = function(){
    console.log('onopen');
  }
  
  //
  session.onmessage = function(event){
    drawColor(event.data);
    drawBoard(event.data);
    drawMessage(event.data);
  }

  //
  session.onerror = function(error){
  }
  session.onclose = function(error){
    drawMessage('{"action": "connection refused"}')
  }
}

//
//
function onClickDisc(disc){
  var x = disc.getAttribute("x");
  var y = disc.getAttribute("y");
  console.log('{"x":'+x+',"y":'+y+"}");
  session.send('{"x":'+x+',"y":'+y+"}")
}

//
//
function register(role, name){
  session.send('{"role":"'+role+'","name":"'+name+'"}')
}


// --------------------------------------------------
// View
// --------------------------------------------------

//
//
function drawColor(data){
  var clr = $.parseJSON(data)["color"];
  if(clr==null){return;}
  if(clr == "b"){
    clr = "your color is black"
    $('#color').html('<h4>'+ clr +'</h2>');
  }else if(clr == "w"){
    clr = "your color is white"
    $('#color').html('<h4>'+ clr +'</h2>');
  }else{
    $('#color').html('<h4>'+ clr +'</h2>');
  }
}

//
//
function drawMessage(data){
  var msg = $.parseJSON(data)["action"];
  if(msg=='finish'){
    msg += ": " + $.parseJSON(data)["result"];
  }
  $('#message').html('<h1>'+ msg +'</h1>');

}

//
//
function drawBoard(data){
  console.log("start");

  var stones = $.parseJSON(data)["board"];
  var board = [];

  console.log(stones)

  board.push('<table>');
  if(stones != ""){
    board.push('<tr>')
    board.push('<th></th>');
    board.push('<th>0</th>');
    board.push('<th>1</th>');
    board.push('<th>2</th>');
    board.push('<th>3</th>');
    board.push('<th>4</th>');
    board.push('<th>5</th>');
    board.push('<th>6</th>');
    board.push('<th>7</th>');
    board.push('</tr>');
  }
  for(var y=0; y<stones.length; y++){
    board.push('<tr>');
    board.push('<th>'+y+'</th>');
    for(var x=0;x<stones[y].length; x++){
      board.push('<td class="cell ');
      if(stones[y][x] == 'b'){
        board.push('black');
      }else if(stones[y][x] == 'w'){
        board.push('white');
      }else{
        board.push('empty');
      }
      board.push('">');
      board.push('<span class="disc"');
      board.push(' x=');
      board.push(x);
      board.push(' y=');
      board.push(y);
      board.push(' onClick="onClickDisc(this)"></span>');
      board.push('</td>');
    }

    board.push('</tr>');
  }
  board.push('</table>');

  $('#game-board').html(board.join(''));

  console.log("end");
}

