const CheckDotVerificationProtocolContract = artifacts.require("CheckDotVerificationProtocolContract");

module.exports = function(deployer) {
  //local 0x79deC2de93f9B16DD12Bc6277b33b0c81f4D74C7
  // prd 0x0cBD6fAdcF8096cC9A43d90B45F65826102e3eCE
  deployer.deploy(CheckDotVerificationProtocolContract, "0x0cBD6fAdcF8096cC9A43d90B45F65826102e3eCE");
};
