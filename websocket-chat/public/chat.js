var wsUri = "/api/chat";
var input;
var output;

window.addEventListener("load", init, false);

function init() {
    input = document.getElementById("input");
    output = document.getElementById("output");
}

function connect() {
    const urlParams = new URLSearchParams(window.location.search);
    const nameParam = urlParams.get('username');
    if (nameParam == undefined) {
        writeToScreen("You forgot to tell us your name");
        return
    }
    const channelParam = urlParams.get('channel');
    if (channelParam == undefined) {
        writeToScreen("You forgot to select a channel");
        return
    }
    let uri = `${wsUri}?username=${nameParam}&channel=${channelParam}`
    openWebSocket(uri)

    input.style.display = 'block'
    document.getElementById("connectButton").style.display = 'none'
    document.getElementById("loggedIn").innerText = `Logged in as ${nameParam}`
    document.getElementById("title").innerText = `#${channelParam}`
}

function openWebSocket(uri) {
    websocket = new WebSocket(uri);
    websocket.onclose = function(evt) { writeToScreen("DISCONNECTED"); };
    websocket.onmessage = function(evt) { writeToScreen('<span style="color: blue;">' + evt.data + '</span>'); };
}

function writeToScreen(message) {
    var pre = document.createElement("p");
    pre.innerHTML = message;
    output.appendChild(pre);
}

function inputEnter() {
    if (input.value == "") {
        return
    }
    websocket.send(input.value)
    input.value = ""
}
