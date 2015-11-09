require("bootstrap-webpack");
require("./../coffee/screen.coffee");

var img1 = document.createElement("img");
img1.src = require("./../image/small.png");
document.body.appendChild(img1);

var img2 = document.createElement("img");
img2.src = require("./../image/big.png");
document.body.appendChild(img2);

console.log(require("./content.js"));