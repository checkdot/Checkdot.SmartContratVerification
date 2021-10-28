// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev CheckDotNotice structure from SmartContractVerification
 */
struct CheckDotNotice {
    uint256 blockNumber;
    uint8 trustIndice;
}

/**
 * @dev CheckDotVerification structure from SmartContractVerification
 */
struct CheckDotVerification {
    address wallet;
    uint256 index;
    uint256 blockNumber;
    uint256 rewardsAmount;
    uint256 rewardsWalletAmount;
    uint256 trustIndice;
    CheckDotNotice[] notices;
    uint256 noticesIndex;
    uint256 maxNotices;
    address[] wallets;
    string data;
}

/**
 * @dev CheckDotValidator structure from SmartContractVerification
 */
struct CheckDotValidator {
    address wallet;
    uint256 amount;
}

/**
 * @dev Implementation of the {CheckDot Smart Contract Verification} Contract
 */
contract CheckDotSmartContractVerificationContract {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    /**
     * @dev Manager of the contract to update approvalNumber into the contract
     */
    address private _owner;
    /**
     * @dev Address of the CDT token hash: {CDT address}
     */
    address private _cdtTokenAddress;

    uint256 private _verificationsIndex;
    mapping(uint256 => CheckDotVerification) private _verifications;

    mapping(address => CheckDotValidator) private _validators;

    uint256 private _defaultRewardsAmount;
    uint256 private _defaultMaxNotices;
    uint256 private _maximumThresholdOfValidators;
    uint256 private _holdingCDTConditionAmount;

    event NewVerification(uint256 index, address wallet);

    constructor(address cdtAddr) {
        _verificationsIndex = 1;
        _cdtTokenAddress = cdtAddr;
        _owner = msg.sender;
        _defaultRewardsAmount = 1;
        _defaultMaxNotices = 1;
        _holdingCDTConditionAmount = 30;
        _maximumThresholdOfValidators = 100;
    }

    /**
     * @dev Check that the transaction sender is the CDT owner
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the owner can do this action");
        _;
    }

    /**
     * @dev See CheckDotVerification count
     */
    function getVerificationsLength() public view returns (uint256) {
        return _verificationsIndex;
    }

    /**
     * @dev See defaultMaxNotices
     */
    function getDefaultMaxNotices() public view returns (uint256) {
        return _defaultMaxNotices;
    }

    /**
     * @dev Set DefaultMaxNotices value
     */
    function setDefaultMaxNotices(uint256 _newDefaultMaxNotices) public payable onlyOwner {
        _defaultMaxNotices = _newDefaultMaxNotices;
    }

    /**
     * @dev See defaultRewardsAmount
     */
    function getDefaultRewardsAmount() public view returns (uint256) {
        return _defaultRewardsAmount;
    }

    /**
     * @dev Set the DefaultRewardsAmount
     */
    function setDefaultRewardsAmount(uint256 _newDefaultRewardsAmount) public payable onlyOwner {
        _defaultRewardsAmount = _newDefaultRewardsAmount;
    }

    /**
     * @dev See maximumThresholdOfValidators
     */
    function getMaximumThresholdOfValidators() public view returns (uint256) {
        return _maximumThresholdOfValidators;
    }

    /**
     * @dev Set the MaximumThresholdOfValidators
     */
    function setMaximumThresholdOfValidators(uint256 _newMaximumThresholdOfValidators) public payable onlyOwner {
        _maximumThresholdOfValidators = _newMaximumThresholdOfValidators;
    }

    /**
     * @dev See the CDT Condition amount for be validator
     */
    function getHoldingCDTConditionAmount() public view returns (uint256) {
        return _holdingCDTConditionAmount;
    }

    /**
     * @dev Set the CDT Condition amount for be validator
     */
    function setHoldingCDTConditionAmount(uint256 _amount) public payable onlyOwner {
        _holdingCDTConditionAmount = _amount;
    }

    /**
     * @dev Returns this CheckDotVerification of the _verificationIndex.
     *
     * Requirements:
     *
     * - `_verificationIndex` must be inferior of _verificationsIndex.
     */
    function getVerification(uint256 _verificationIndex) public view returns (CheckDotVerification memory) {
        require(_verificationIndex < _verificationsIndex, "Verification not found");
        return _verifications[_verificationIndex];
    }

    function getVerifications(int256 page, int256 pageSize) public view returns (CheckDotVerification[] memory) {
        int256 queryStartVerificationIndex = int256(getVerificationsLength()).sub(pageSize.mul(page)).add(pageSize).sub(1);
        require(queryStartVerificationIndex >= 0, "Out of bounds");

        int256 queryEndVerificationIndex = queryStartVerificationIndex.sub(pageSize);
        if (queryEndVerificationIndex < 0) {
            queryEndVerificationIndex = 0;
        }

        int256 currentVerificationIndex = queryStartVerificationIndex;
        require(uint256(currentVerificationIndex) <= getVerificationsLength().sub(1), "Out of bounds");

        CheckDotVerification[] memory results = new CheckDotVerification[](uint256(currentVerificationIndex - queryEndVerificationIndex));
        uint256 index = 0;

        for (currentVerificationIndex; currentVerificationIndex > queryEndVerificationIndex; currentVerificationIndex--) {
            uint256 currentVerificationIndexAsUnsigned = uint256(currentVerificationIndex);
            if (currentVerificationIndexAsUnsigned <= getVerificationsLength().sub(1)) {
                results[index] = getVerification(currentVerificationIndexAsUnsigned);
            }
            index++;
        }
        return results;
    }

    /**
     * @dev Create CheckDotVerification and moves (`_amount` or `_defaultRewardsAmount`)
     * of tokens from `sender` to `address(this)`.
     */
    function createVerification(
        string calldata _data,
        uint256 _amount,
        uint256 _maxNotices
    ) public {
        IERC20 cdtToken = IERC20(_cdtTokenAddress);
        uint256 rewardsAmount = _amount > 0 ? _amount : _defaultRewardsAmount;

        require(_maxNotices <= _maximumThresholdOfValidators, "Maximum Threshold of validators exceeded");
        require(cdtToken.balanceOf(msg.sender) >= rewardsAmount, "Insufficient funds from the sender");
        require(cdtToken.transferFrom(msg.sender, address(this), rewardsAmount) == true, "Error transferFrom on the contract");
        uint256 index = _verificationsIndex++;
        CheckDotVerification storage ask = _verifications[index];

        ask.wallet = msg.sender;
        ask.index = index;
        ask.blockNumber = block.number;
        ask.rewardsAmount = rewardsAmount;
        ask.rewardsWalletAmount = rewardsAmount;
        ask.trustIndice = 0;
        ask.noticesIndex = 0;
        ask.maxNotices = _maxNotices > 0 ? _maxNotices : _defaultMaxNotices;
        ask.data = _data;

        emit NewVerification(ask.index, ask.wallet);
    }

    /**
     * @dev Create notice and move the part of `ask.rewardsAmount` to the `sender`.
     */
    function notice(
        uint256 _verificationIndex,
        uint8 _trustIndice
    ) public {
        IERC20 cdtToken = IERC20(_cdtTokenAddress);

        require(cdtToken.balanceOf(msg.sender) >= _holdingCDTConditionAmount, "No Eligible for the validation");
        require(_verificationIndex < _verificationsIndex, "Verification not found");
        CheckDotVerification storage ask = _verifications[_verificationIndex];

        require(ask.wallet != msg.sender, "The asker is not authorized to add notice on this verification");
        require(ask.noticesIndex < ask.maxNotices && ask.rewardsAmount > 0, "The verification is already finished");
        for (uint256 i = 0; i < ask.wallets.length; i++) {
            require(msg.sender != ask.wallets[i], "You have already add notice on this verification");
        }

        ask.wallets.push(msg.sender);
        ask.notices.push(CheckDotNotice(block.number, _trustIndice));
        ask.noticesIndex++;

        CheckDotValidator storage validator = _validators[msg.sender];

        validator.wallet = msg.sender;
        // Rewards
        uint256 validatorRewards = ask.rewardsAmount / ask.maxNotices;

        validator.amount += validatorRewards;
        ask.rewardsWalletAmount -= validatorRewards;
    }

    /**
     * @dev Stop CheckDotVerification verification and Move the remaining
     * `ask.rewardAmount` from `address(this)` to `sender`
     */
    function stopVerification(uint256 _verificationIndex) public {
        IERC20 cdtToken = IERC20(_cdtTokenAddress);

        require(_verificationIndex < _verificationsIndex, "Contract not found");
        CheckDotVerification storage ask = _verifications[_verificationIndex];
        require(ask.wallet == msg.sender, "Only owners is authorized to withdraw");
        require(ask.rewardsWalletAmount > 0, "reward Amount is Empty");
        require(cdtToken.transfer(msg.sender, ask.rewardsWalletAmount) == true, "Error transfer on the contract");
        ask.rewardsAmount = 0;
        ask.rewardsWalletAmount = 0;
    }

    /**
     * @dev Claim the personnal rewards.
     */
    function claimRewards() public {
        IERC20 cdtToken = IERC20(_cdtTokenAddress);
        CheckDotValidator storage validator = _validators[msg.sender];

        require(validator.amount > 0, "Validator rewards is empty");
        require(cdtToken.transfer(msg.sender, validator.amount) == true, "Error transfer on the contract");
        validator.amount = 0;
    }

}
