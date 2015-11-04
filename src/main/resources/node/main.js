var webpack = require("webpack");

// returns a Compiler instance
webpack({
    // configuration
    context: __dirname,
    entry: "./entry.js",
    debug: true,
    output: {
        path: __dirname,
        filename: "myBundle.js"
    },
    module: {
        loaders: [
            { test: /\.css$/, loader: "style!css" }
        ]
    }
}, function(err, stats) {
    // ...
});
