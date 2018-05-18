module.exports = {
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  networks: {
    development: {
      host: "localhost",
      port: 7545,
      gas: 4700000,
      gasPrice: 65000000000,
      network_id: "*" // Match any network id
    },
    "ropsten": {
      host: "localhost",
      port: 8545,
      gas: 4700000,
      gasPrice: 65000000000,
      network_id: 3,
    },
    "ropsten_queen": {
      host: "195.176.65.234",
      port: 8745,
      gas: 4700000,
      gasPrice: 65000000000,
      network_id: 3,
    }
  }
}
