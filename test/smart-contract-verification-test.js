const truffleAssert = require('truffle-assertions');
const contractTruffle = require('truffle-contract');
const { toWei, toBN } = web3.utils;

/* CheckDotToken Provider */
const checkdotTokenArtifact = require('../../CheckDot.CheckDotERC20Contract/build/contracts/CheckDot.json');
const CheckdotTokenContract = contractTruffle(checkdotTokenArtifact);
CheckdotTokenContract.setProvider(web3.currentProvider);

/* CheckDotSmartContractVerification Artifact */
const CheckDotSmartContractVerificationContract = artifacts.require('CheckDotSmartContractVerificationContract');

contract('CheckDotSmartContractVerificationContract', async (accounts) => {
  let tokenInstance;
  let verificationContractInstance;

  let owner;
  let initiator;
  let validatorOne;
  let validatorTwo;
  let validatorThree;

  let verificationIndex;

  before(async () => {
    // instances
    tokenInstance = await CheckdotTokenContract.deployed();
    verificationContractInstance = await CheckDotSmartContractVerificationContract.deployed();

    console.log('Contract address:', verificationContractInstance.address);

    // accounts
    owner = accounts[0];
    initiator = accounts[1];
    noticer = accounts[2];
    validatorOne = accounts[3];
    validatorTwo = accounts[4];
    validatorThree = accounts[5];
  });

  it('DefaultMaxNotices should be modified by owner', async () => {
    // get initial DefaultMaxNotices
    const initialDefaultMaxNotices = await verificationContractInstance.getDefaultMaxNotices({
      from: owner,
    });

    await verificationContractInstance.setDefaultMaxNotices(2, {
      from: owner,
    });

    // compare DefaultMaxNotices with initial DefaultMaxNotices
    const contractDefaultMaxNotices = await verificationContractInstance.getDefaultMaxNotices({
      from: owner,
    });

    assert.equal(
      initialDefaultMaxNotices,
      1,
      'should have initial DefaultMaxNotices of 1'
    );

    assert.equal(
      contractDefaultMaxNotices,
      2,
      'should have updated DefaultMaxNotices of 2'
    );

  });
  
  it('verification should be created and balance of initiator should have CDT amount removed from balance', async () => {
      // initial CDT transfert
      const initialTransferAmount = toWei('2', 'ether');
      await truffleAssert.passes(tokenInstance.transfer(initiator, initialTransferAmount, { from: owner }), 'initial transfer failed');

      // // store initiator initial CDT balance
      const initiatorInitialBalance = await tokenInstance.balanceOf(initiator);
      // // approve CDT
      const approveAmount = toWei('1.5', 'ether');
      await tokenInstance.approve(verificationContractInstance.address, approveAmount, {
        from: initiator,
      });

      // create verification
      const data = "{ \"test\": \"xxx\" }";
      const amount = toWei('1', 'ether');
      const numberOfValidatorNeeded = 2;

      await verificationContractInstance.createVerification(data, amount, numberOfValidatorNeeded, {
        from: initiator,
      });

      // compare initiator current CDT balance with initial balance
      const initiatorCurrentBalance = await tokenInstance.balanceOf(initiator);
      assert.equal(
        initiatorCurrentBalance.toString(),
        initiatorInitialBalance.sub(toBN(amount)).toString(),
        'should have CDT removed from balance'
      );

      const latestVerifications = await verificationContractInstance.getVerifications(1, 1, {
        from: initiator,
      });

      assert.equal(
        initiator,
        latestVerifications[0].wallet,
        'should contains verification created by initiator'
      );

      verificationIndex = latestVerifications[0].index;
  });

  // it('notice should be added in verification and balance of noticer should have CDT reward amount added from balance', async () => {
  //   // store initiator initial CDT balance
  //   const noticerInitialBalance = await tokenInstance.balanceOf(noticer);

  //   // create notice
  //   const trustIndice = 100;

  //   await verificationContractInstance.notice(verificationIndex, trustIndice, {
  //     from: noticer,
  //   });

  //   // compare noticer current CDT balance with initial balance
  //   const noticerCurrentBalance = await tokenInstance.balanceOf(noticer);
  //   assert.equal(
  //     noticerCurrentBalance.toString(),
  //     noticerInitialBalance.add(toBN(toWei('0.9', 'ether'))).toString(), // 90% payout
  //     'should have CDT added from balance'
  //   );

  //   const verification = await verificationContractInstance.getVerification(verificationIndex, {
  //     from: initiator,
  //   });

  //   assert.equal(
  //     trustIndice,
  //     verification.notices[0].trustIndice,
  //     'should contains verification'
  //   );
  // });

  it('approvals should be created and balance of validators should have CDT rewards amount added from balance', async () => {
    // // initial CDT transfert
    const initialTransferAmount = toWei('30', 'ether');
    await truffleAssert.passes(tokenInstance.transfer(validatorOne, initialTransferAmount, { from: owner }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(validatorTwo, initialTransferAmount, { from: owner }), 'initial transfer failed');
    // store validators initial CDT balance
    const validatorOneInitialBalance = await tokenInstance.balanceOf(validatorOne);
    const validatorTwoInitialBalance = await tokenInstance.balanceOf(validatorTwo);

    // create validations
    await verificationContractInstance.notice(verificationIndex, 100, {
      from: validatorOne,
    });
    await verificationContractInstance.notice(verificationIndex, 100, {
      from: validatorTwo,
    });

    await verificationContractInstance.claimRewards({
      from: validatorOne,
    });
    await verificationContractInstance.claimRewards({
      from: validatorTwo,
    });

    // compare noticer current CDT balance with initial balance
    const validatorOneCurrentBalance = await tokenInstance.balanceOf(validatorOne);
    const validatorTwoCurrentBalance = await tokenInstance.balanceOf(validatorTwo);

    assert.equal(
      validatorOneCurrentBalance.toString(),
      validatorOneInitialBalance.add(toBN(toWei('0.5', 'ether'))).toString(), // (10% / approvalNumber) payout
      'validatorOne should have CDT added from balance'
    );

    assert.equal(
      validatorTwoCurrentBalance.toString(),
      validatorTwoInitialBalance.add(toBN(toWei('0.5', 'ether'))).toString(), // (10% / approvalNumber) payout
      'validatorTwo should have CDT added from balance'
    );

    const verification = await verificationContractInstance.getVerification(verificationIndex, {
      from: initiator,
    });

    assert.equal(
      2,
      verification.notices.length,
      'should contains 2 verification'
    );

    await truffleAssert.passes(tokenInstance.transfer(owner, initialTransferAmount, { from: validatorOne  }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(owner, initialTransferAmount, { from: validatorTwo }), 'initial transfer failed');

  });

  it('verification should be stopped and balance of initiator should have CDT amount removed from balance', async () => {
    // initial CDT transfert
    const initialTransferAmount = toWei('2', 'ether');
    await truffleAssert.passes(tokenInstance.transfer(initiator, initialTransferAmount, { from: owner }), 'initial transfer failed');

    // // store initiator initial CDT balance
    const initiatorInitialBalance = await tokenInstance.balanceOf(initiator);

    // // approve CDT
    const approveAmount = toWei('1.5', 'ether');
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, {
      from: initiator,
    });

    // create verification
    const data = "{ \"test2\": \"jsjsjs\"}";
    const amount = toWei('1', 'ether');
    const numberOfValidatorNeeded = 2;

    await verificationContractInstance.createVerification(data, amount, numberOfValidatorNeeded, {
      from: initiator,
    });

    // compare initiator current CDT balance with initial balance
    const initiatorCurrentBalance = await tokenInstance.balanceOf(initiator);
    assert.equal(
      initiatorCurrentBalance.toString(),
      initiatorInitialBalance.sub(toBN(amount)).toString(),
      'should have CDT removed from balance'
    );

    const latestVerifications = await verificationContractInstance.getVerifications(1, 1, {
      from: initiator,
    });

    assert.equal(
      initiator,
      latestVerifications[0].wallet,
      'should contains verification created by initiator'
    );

    await verificationContractInstance.stopVerification(latestVerifications[0].index, {
      from: initiator,
    });

  });
});