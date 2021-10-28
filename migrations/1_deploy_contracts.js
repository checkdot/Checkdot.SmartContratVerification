const CheckDotContract = artifacts.require("CheckDotSmartContractVerificationContract");

module.exports = function(deployer) {
  const checkDotTokenContractAddresses = {
    '1': '0x1dCF92BfA88082d1c5FE57e93df21Aa82396CF5a', // mainnet
    '3': '0xB5426AF00DEd584F337a0fb3990577Dce4AD2027', // ropsten
    '5777': '0x79deC2de93f9B16DD12Bc6277b33b0c81f4D74C7' // local
  };

  deployer.deploy(CheckDotContract, checkDotTokenContractAddresses['3']);
};
