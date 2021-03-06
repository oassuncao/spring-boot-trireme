var webpack = require("webpack");
var console = require("console");

// returns a Compiler instance
webpack({
    // configuration
    context: __dirname,
    entry:  {
        app: "./js/entry.js",
        vendor: ['jquery']
    },
    output: {
        path: __dirname + "/dist",
        filename: "bundle.js"
    },
    plugins: [
        new webpack.optimize.CommonsChunkPlugin('vendor', 'vendor.js'),
        new webpack.optimize.UglifyJsPlugin({
            compress: {
                warnings: false
            }
        })
    ],
    module: {
        loaders: [
            /*css loaders*/
            { test: /\.css$/, loader: "style!css" },
            { test: /\.less$/, loader: "style!css!less" },

            /*js loaders*/
            { test: /bootstrap\/js\//, loader: 'imports?jQuery=jquery' },
            { test: /\.coffee$/, loader: "coffee-loader" },
            //{ test: /\.jsx$/, exclude: /(node_modules|bower_components)/, loader: 'babel'} disabled, with trireme receive this error 'Cannot call method "split" of undefined'

            /*file loaders*/
            { test: /\.(png|jpg)$/, loader: 'url-loader?limit=8192' },
            { test: /\.woff(\?v=\d+\.\d+\.\d+)?$/,   loader: "url?limit=10000&mimetype=application/font-woff" },
            { test: /\.ttf(\?v=\d+\.\d+\.\d+)?$/,    loader: "url?limit=10000&mimetype=application/octet-stream" },
            { test: /\.eot(\?v=\d+\.\d+\.\d+)?$/,    loader: "file" },
            { test: /\.svg(\?v=\d+\.\d+\.\d+)?$/,    loader: "url?limit=10000&mimetype=image/svg+xml" }
        ]
    }
}, function(err, stats) {
    /*
    var json = stats.toJson({
        errorDetails: true
    });
    console.log(json);
    */
});
