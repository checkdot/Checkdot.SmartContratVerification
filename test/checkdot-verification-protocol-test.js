const truffleAssert = require('truffle-assertions');
const contractTruffle = require('truffle-contract');
const { toWei, toBN } = web3.utils;

/* CheckDotToken Provider */
const checkdotTokenArtifact = require('../../CheckDot.CheckDotERC20Contract/build/contracts/CheckDot.json');
const CheckdotTokenContract = contractTruffle(checkdotTokenArtifact);
CheckdotTokenContract.setProvider(web3.currentProvider);

/* CheckDotSmartContractVerification Artifact */
const CheckDotSmartContractVerificationContract = artifacts.require('CheckDotVerificationProtocolContract');

contract('CheckDotSmartContractVerificationContract', async (accounts) => {
  let tokenInstance;
  let verificationContractInstance;

  let owner;
  let validatorOne;
  let validatorTwo;
  let validatorThree;
  let validatorFour;
  let validatorFive;

  let verificationIndex;

  before(async () => {
    // instances
    tokenInstance = await CheckdotTokenContract.deployed();
    verificationContractInstance = await CheckDotSmartContractVerificationContract.deployed();

    console.log('Contract address:', verificationContractInstance.address);

    // accounts
    owner = accounts[0];
    validatorOne = accounts[1];
    validatorTwo = accounts[2];
    validatorThree = accounts[3];
    validatorFour = accounts[4];
    validatorFive = accounts[5];
  });

  it('Set min cap', async () => {
    await verificationContractInstance.setMinCap("5", {
      from: owner
    });

    const settings = await verificationContractInstance.getSettings({
      from: owner
    });

    assert.equal(
      settings.MIN_CAP.toString(),
      "5",
      'Min Cap Not equals to 5'
    );
  })

  it('Add Question', async () => {
    await verificationContractInstance.setQuestion("1",
      `Please open the pdf document provided above.
      Then search the document for the word or and write the following text:
      #hash
      If the text is not written in the document please answer with No.
      If it is not, please answer with Yes.`,
      [
        "Yes", "No"
      ],
      "Yes",
    {
      from: owner,
    });

    const question = await verificationContractInstance.getQuestion("1", {
      from: owner,
    });

    assert.equal(
      question.ID,
      1,
      'Question isn\'t added'
    );

  });

  it('verification should be created and balance of initiator should have CDT amount removed from balance', async () => {
    // // store initiator initial CDT balance
    const initiatorInitialBalance = await tokenInstance.balanceOf(owner);
    // // approve CDT
    const approveAmount = toWei('10000', 'ether');
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, {
      from: owner,
    });

    // create verification
    const data = JSON.stringify({
      pdfAuditUrl: "https://github.com/Quillhash/Audit_Reports/blob/master/Checkdot%20Smart%20Contract%20Audit%20Report%20-%20QuillAudits.pdf",
      githubRepositoryUrl: "https://github.com/checkdot/CheckdotERC20Contract",
      commitHash: "1f68a6acd49ae28655fae5882384deb69afd2a7d"
    });

    const amount = toWei('5.05', 'ether');

    const settings = await verificationContractInstance.getSettings({
      from: owner
    });

    await verificationContractInstance.init("1", data, "5", {
      from: owner
    });

    // compare initiator current CDT balance with initial balance
    const initiatorCurrentBalance = await tokenInstance.balanceOf(owner);
    
    assert.equal(
      initiatorCurrentBalance.toString(),
      initiatorInitialBalance.sub(toBN(amount)).toString(),
      'should have CDT removed from balance'
    );

    const latestVerifications = await verificationContractInstance.getVerifications("1", "10", {
      from: validatorOne,
    });

    assert.equal(
      owner,
      latestVerifications[latestVerifications.length - 1].INITIATOR,
      'should contains verification created by initiator'
    );

    const latestInProgressVerification = latestVerifications[latestVerifications.length - 1];

    assert.equal(
      owner,
      latestInProgressVerification.INITIATOR,
      'should contains verification created by initiator'
    );

    assert.equal(
      latestInProgressVerification.NUMBER_OF_ANSWER_SLOTS,
      5,
      'should contains verification with 5 needed Validators'
    );

    assert.equal(
      latestInProgressVerification.REWARD_AMOUNT,
      toBN(toWei('5', 'ether')).toString(),
      'should contains verification 5 CDT reward amount'
    );

    verificationIndex = latestInProgressVerification.index;
  });

  it('approvals should be created and warranty should be deposited', async () => {
    //Approuve
    const approveAmount = toWei('10000', 'ether');
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, { from: validatorOne });
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, { from: validatorTwo });
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, { from: validatorThree });
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, { from: validatorFour });
    await tokenInstance.approve(verificationContractInstance.address, approveAmount, { from: validatorFive });

    // // initial CDT transfert
    const initialTransferAmount = toWei('30', 'ether');
    await truffleAssert.passes(tokenInstance.transfer(validatorOne, initialTransferAmount, { from: owner }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(validatorTwo, initialTransferAmount, { from: owner }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(validatorThree, initialTransferAmount, { from: owner }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(validatorFour, initialTransferAmount, { from: owner }), 'initial transfer failed');
    await truffleAssert.passes(tokenInstance.transfer(validatorFive, initialTransferAmount, { from: owner }), 'initial transfer failed');
    // store validators initial CDT balance
    const validatorOneInitialBalance = await tokenInstance.balanceOf(validatorOne);
    const validatorTwoInitialBalance = await tokenInstance.balanceOf(validatorTwo);
    const validatorThreeInitialBalance = await tokenInstance.balanceOf(validatorThree);
    const validatorFourInitialBalance = await tokenInstance.balanceOf(validatorFour);
    const validatorFiveInitialBalance = await tokenInstance.balanceOf(validatorFive);

    // create validations
    await verificationContractInstance.addWarranty(initialTransferAmount, { from: validatorOne });
    await verificationContractInstance.addWarranty(initialTransferAmount, { from: validatorTwo });
    await verificationContractInstance.addWarranty(initialTransferAmount, { from: validatorThree });
    await verificationContractInstance.addWarranty(initialTransferAmount, { from: validatorFour });
    await verificationContractInstance.addWarranty(initialTransferAmount, { from: validatorFive });


    const latestInProgressVerifications = await verificationContractInstance.getVerifications(1, 1, {
      from: validatorOne,
    });

    console.log(latestInProgressVerifications);

    const verification = latestInProgressVerifications[0];

    await verificationContractInstance.reply(verification.ID, verification.ANSWERS[0], {
      from: validatorOne,
    });
    await verificationContractInstance.reply(verification.ID, verification.ANSWERS[0], {
      from: validatorTwo,
    });
    await verificationContractInstance.reply(verification.ID, verification.ANSWERS[0], {
      from: validatorThree,
    });
    await verificationContractInstance.reply(verification.ID, verification.ANSWERS[0], {
      from: validatorFour,
    });
    await verificationContractInstance.reply(verification.ID, verification.ANSWERS[1], {
      from: validatorFive,
    });


    await verificationContractInstance.evaluate(verification.ID, {
      from: owner
    });

    await verificationContractInstance.withdrawAll({
      from: validatorOne,
    });

    const validatorOneInformation = await verificationContractInstance.getMyValidator({
      from: validatorFive,
    });

    const vv = await verificationContractInstance.getVerification(verification.ID, {
      from: owner,
    });

    // compare noticer current CDT balance with initial balance
    const validatorOneCurrentBalance = await tokenInstance.balanceOf(validatorOne);
    const validatorFiveCurrentBalance = await tokenInstance.balanceOf(validatorFive);

    assert.equal(
      validatorOneCurrentBalance.toString(),
      validatorOneInitialBalance.add(toBN(toWei('1.25', 'ether'))).toString(), // (10% / approvalNumber) payout
      'validatorOne should have CDT added from balance'
    );
  });

});