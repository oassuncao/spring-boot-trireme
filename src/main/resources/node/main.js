var webpack = require("webpack");

// returns a Compiler instance
webpack({
    // configuration
    context: __dirname,
    entry:  {
        app: "./entry.js",
        vendor: ['jquery']
    },
    debug: true,
    output: {
        path: __dirname + "/dist",
        filename: "bundle.js"
    },
    plugins: [
        new webpack.optimize.CommonsChunkPlugin('vendor', 'vendor.js')/*,
        new webpack.optimize.UglifyJsPlugin({
            compress: {
                warnings: false
            }
        })*/
    ],
    module: {
        loaders: [
            { test: /\.css$/, loader: "style!css" },
            { test: /\.less$/, loader: "style!css!less" },
            { test: /\.coffee$/, loader: "coffee-loader" },
            { test: /\.(png|jpg)$/, loader: 'url-loader?limit=8192' },
            { test: /\.jsx?$/, exclude: /(node_modules|bower_components)/, loader: 'babel'}
        ]
    }
}, function(err, stats) {
    // ...
});
