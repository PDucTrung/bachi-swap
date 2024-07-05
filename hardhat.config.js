require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    taiko: {
      url: process.env.RPC_URL,
      accounts: [process.env.YOUR_PRIVATE_KEY],
    },
  },
};