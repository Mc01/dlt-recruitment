module.exports = {
    networks: {
        ganache: {
            host: "localhost",
            port: 7545,
            network_id: "*",
        },
    },
    mocha: {
        reporter: 'eth-gas-reporter',
    },
    compilers: {
        solc: {
            version: '^0.7.6',
        },
    },
};
