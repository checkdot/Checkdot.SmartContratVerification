// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);
}

struct Verification {
    address INITIATOR;
    uint256 ID;
    uint256 BLOCK_NUMBER;
    uint256 REWARD_AMOUNT;
    uint256 REWARD_WALLET_AMOUNT;
    uint256 SCORE;
    string QUESTION;
    string[] ANSWERS;
    uint256 NUMBER_OF_ANSWER_SLOTS;
    address[] PARTICIPATORS;
    address[] WINNERS;
    address[] LOOSERS;
    string DATA;
    uint256 QUESTION_ID;
    uint256 STATUS;
    uint256 CDT_PER_QUESTION;
}

struct Participation {
    uint256 VERIFICATION_ID;
    uint256 REWARD_AMOUNT;
    uint256 BURNT_WARRANTY;
}

struct Validator {
    address WALLET;
    uint256 AMOUNT;
    uint256 WARRANTY_AMOUNT;
    uint256 LOCKED_WARRANTY_AMOUNT;
    uint256 BURNT_WARRANTY;
    Participation[] PARTICICATIONS;
}

struct QuestionWithAnswer {
    uint256 ID;
    string QUESTION;
    string[] ANSWERS;
    string ANSWER;
}

struct Answer {
    address WALLET;
    string ANSWER;
}

library Numeric {
    function isNumeric(string memory _value) internal pure returns (bool _ret) {
        bytes memory _bytesValue = bytes(_value);
        for(uint i = _bytesValue.length-1; i >= 0 && i < _bytesValue.length; i--) {
            if (uint8(_bytesValue[i]) < 48 && uint8(_bytesValue[i]) > 57) {
                return false;
            }
        }
        return true;
    }
}

/**
 * @dev Implementation of the {CheckDot Smart Contract Verification} Contract Version 1
 * 
 * Simple schema representation:
 *
 * o------o       o--------------------o       o------------o
 * | ASKs | ----> | Validators answers | ----> | Evaluation |
 * o------o       o--------------------o       o------------o
 *
 */
contract CheckDotVerificationProtocolContract {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using Numeric for string;

    /**
     * @dev Manager of the contract to update approvalNumber into the contract.
     */
    address private _owner;

    /**
     * @dev Address of the CDT token hash: {CDT address}.
     */
    IERC20 private _cdtToken;

    struct VerificationSettings {
        uint256 MAX_CAP;
        uint256 MIN_CAP;
        uint256 CDT_PER_QUESTION;
        /**
        * @dev Percentage of Decentralized fees: 1% (0.5% for CheckDot - 0.5% are burnt).
        */
        uint256 SERVICE_FEE;
    }

    struct VerificationStatistics {
        uint256 TOTAL_CDT_BURNT;
        uint256 TOTAL_CDT_FEE;
        uint256 TOTAL_CDT_WARRANTY;
    }

    VerificationSettings public _settings;

    VerificationStatistics public _statistics;

    uint256 private _checkDotCollectedFeesAmount = 0;

    // MAPPING

    uint256 private                                        _verificationsIndex;
    mapping(uint256 => Verification) private       _verifications;
    mapping(uint256 => Answer[]) private           _verificationsAnswers;
    mapping(address => Validator) private          _validators;
    mapping(uint256 => QuestionWithAnswer) private _questions;

    event NewVerification(uint256 id, address initiator);
    event UpdateVerification(uint256 id, address initiator);

    constructor(address cdtTokenAddress) {
        _verificationsIndex = 1;
        _cdtToken = IERC20(cdtTokenAddress);
        _owner = msg.sender;
        _settings.CDT_PER_QUESTION = 10**18;
        _settings.MIN_CAP = 5;
        _settings.MAX_CAP = 500;
        _settings.SERVICE_FEE = 1;
    }

    /**
     * @dev Check that the transaction sender is the CDT owner
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the owner can do this action");
        _;
    }

    // Global SECTION
    function getVerificationsLength() public view returns (uint256) {
        return _verificationsIndex;
    }

    function getSettings() public view returns (VerificationSettings memory) {
        return _settings;
    }

    function getStatistics() public view returns (VerificationStatistics memory) {
        return _statistics;
    }

    // VIEW SECTION
    function getMyValidator() public view returns (Validator memory) {
        Validator storage validator = _validators[msg.sender];
        
        return validator;
    }

    function getVerification(uint256 verificationIndex) public view returns (Verification memory) {
        require(verificationIndex < _verificationsIndex, "Verification not found");
        
        return _verifications[verificationIndex];
    }

    function getVerifications(int256 page, int256 pageSize) public view returns (Verification[] memory) {
        uint256 verificationLength = getVerificationsLength();
        int256 queryStartVerificationIndex = int256(verificationLength).sub(pageSize.mul(page)).add(pageSize).sub(1);
        require(queryStartVerificationIndex >= 0, "Out of bounds");
        int256 queryEndVerificationIndex = queryStartVerificationIndex.sub(pageSize);
        if (queryEndVerificationIndex < 0) {
            queryEndVerificationIndex = 0;
        }
        int256 currentVerificationIndex = queryStartVerificationIndex;
        require(uint256(currentVerificationIndex) <= verificationLength.sub(1), "Out of bounds");
        Verification[] memory results = new Verification[](uint256(currentVerificationIndex - queryEndVerificationIndex));
        uint256 index = 0;

        for (currentVerificationIndex; currentVerificationIndex > queryEndVerificationIndex; currentVerificationIndex--) {
            uint256 currentVerificationIndexAsUnsigned = uint256(currentVerificationIndex);
            if (currentVerificationIndexAsUnsigned <= verificationLength.sub(1)) {
                results[index] = _verifications[currentVerificationIndexAsUnsigned];
            }
            index++;
        }
        return results;
    }

    // END VIEW SECTION

    // PROTOCOL SECTION
    function addWarranty(uint256 amount) public {
        Validator storage validator = _validators[msg.sender];

        require(_cdtToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(_cdtToken.transferFrom(msg.sender, address(this), amount) == true, "Error transfer");
        validator.WALLET = msg.sender;
        validator.WARRANTY_AMOUNT += amount;
    }

    function init(uint256 questionId, string calldata data, uint256 numberOfAnswerCap) public {
        QuestionWithAnswer storage question = _questions[questionId];

        require(question.ID == questionId, "Question not found");
        require(bytes(data).length <= 2000, "Top long data length");
        require(numberOfAnswerCap >= _settings.MIN_CAP && numberOfAnswerCap <= _settings.MAX_CAP, "Invalid cap");

        uint256 rewardsAmount = _settings.CDT_PER_QUESTION.mul(numberOfAnswerCap);
        uint256 checkDotFees = rewardsAmount.mul(_settings.SERVICE_FEE).div(100);
        uint256 transactionCost = checkDotFees + rewardsAmount;

        require(_cdtToken.balanceOf(msg.sender) >= transactionCost, "Insufficient balance");
        require(_cdtToken.transferFrom(msg.sender, address(this), transactionCost) == true, "Error transfer");
        require(_cdtToken.burn(checkDotFees.div(2)) == true, "Error burn");
        _statistics.TOTAL_CDT_BURNT += checkDotFees.div(2);
        _statistics.TOTAL_CDT_FEE += checkDotFees;
        _checkDotCollectedFeesAmount += checkDotFees.div(2);
        uint256 index = _verificationsIndex++;
        Verification storage ask = _verifications[index];

        ask.INITIATOR = msg.sender;
        ask.ID = index;
        ask.BLOCK_NUMBER = block.number;
        ask.REWARD_AMOUNT = rewardsAmount;
        ask.REWARD_WALLET_AMOUNT = rewardsAmount;
        ask.NUMBER_OF_ANSWER_SLOTS = numberOfAnswerCap;
        ask.DATA = data;
        ask.QUESTION = question.QUESTION;
        for (uint i = 0; i < question.ANSWERS.length; i++) {
            ask.ANSWERS.push(question.ANSWERS[i]);
        }
        ask.QUESTION_ID = questionId;
        ask.STATUS = 1;
        ask.CDT_PER_QUESTION = _settings.CDT_PER_QUESTION;

        emit NewVerification(ask.ID, ask.INITIATOR);
    }

    function reply(
        uint256 verificationIndex,
        string calldata answer
    ) public {
        Validator storage validator = _validators[msg.sender];

        require(verificationIndex < _verificationsIndex, "Verification not found");
        Verification storage ask = _verifications[verificationIndex];
        Answer[] storage answers = _verificationsAnswers[verificationIndex];

        require(validator.WARRANTY_AMOUNT >= ask.CDT_PER_QUESTION, "Not Eligible");
        require(ask.STATUS == 1, "Ended");
        require(ask.INITIATOR != msg.sender, "Not authorized");
        require(answers.length < ask.NUMBER_OF_ANSWER_SLOTS, "Ended");
        for (uint256 i = 0; i < ask.PARTICIPATORS.length; i++) {
            require(msg.sender != ask.PARTICIPATORS[i], "Not authorized");
        }

        ask.PARTICIPATORS.push(msg.sender);
        answers.push(Answer(msg.sender, answer));
        validator.WARRANTY_AMOUNT -= ask.CDT_PER_QUESTION;
        validator.LOCKED_WARRANTY_AMOUNT += ask.CDT_PER_QUESTION;
        if (answers.length >= ask.NUMBER_OF_ANSWER_SLOTS) {
            ask.STATUS = 2;
        }
        emit UpdateVerification(ask.ID, ask.INITIATOR);
    }

    function evaluate(uint256 _verificationIndex) public {
        require(_verificationIndex < _verificationsIndex, "Verification not found");
        Verification storage ask = _verifications[_verificationIndex];
        require(ask.STATUS == 2, "Not authorized");

        Answer[] storage answers = _verificationsAnswers[_verificationIndex];
        QuestionWithAnswer storage question = _questions[ask.QUESTION_ID];
        bool dot = false;
        uint256 guaranteeToBurn = 0;
        uint256 sameResponseCount = 0;
        // boucler sur les Reponses
        for (uint256 o = 0; o < answers.length; o++) {
            // Comptage total des reponses identiques
            sameResponseCount = 0;
            for (uint256 o2 = 0; o2 < answers.length; o2++) {
                if (keccak256(bytes(answers[o2].ANSWER)) == keccak256(bytes(answers[o].ANSWER))) { // Qx
                    sameResponseCount += 1;
                }
            }
            // Si le nombre total de reponse identiques et superieur à la majorité la reponse est validé.
            if (sameResponseCount.mul(100).div(answers.length) >= 70) {
                for (uint256 o2 = 0; o2 < answers.length; o2++) {
                    if (keccak256(bytes(answers[o2].ANSWER)) == keccak256(bytes(answers[o].ANSWER))) {
                        ask.WINNERS.push(answers[o2].WALLET);
                    } else {
                        ask.LOOSERS.push(answers[o2].WALLET);
                    }
                }
                ask.SCORE = sameResponseCount.mul(100).div(answers.length);
                // save score if response is valid
                if (keccak256(bytes(question.ANSWER)) == keccak256(bytes("Numeric")) && answers[o].ANSWER.isNumeric()) {
                    dot = true;
                } else if (keccak256(bytes(question.ANSWER)) == keccak256(bytes(answers[o].ANSWER))) {
                    dot = true;
                }
                break ;
            }
        }
        if (dot == true) {
            ask.SCORE = sameResponseCount.mul(100).div(answers.length);
            ask.STATUS = 3;
            // burn les fonds sur les mauvais travailleurs.
            for (uint i = 0; i < ask.LOOSERS.length; i++) {
                Validator storage validator = _validators[ask.LOOSERS[i]];
                // Guarantee
                validator.LOCKED_WARRANTY_AMOUNT -= ask.CDT_PER_QUESTION;
                validator.WARRANTY_AMOUNT += ask.CDT_PER_QUESTION.div(2);
                validator.BURNT_WARRANTY += ask.CDT_PER_QUESTION.div(2);
                guaranteeToBurn += ask.CDT_PER_QUESTION.div(2);
                validator.PARTICICATIONS.push(Participation(ask.ID, 0, ask.CDT_PER_QUESTION.div(2)));
            }

            // ajouter les fonds sur les bons travailleurs.
            for (uint i = 0; i < ask.WINNERS.length; i++) {
                Validator storage validator = _validators[ask.WINNERS[i]];
                // Rewards
                uint256 validatorRewards = ask.REWARD_AMOUNT.div(ask.WINNERS.length);
                validator.AMOUNT += validatorRewards;
                validator.LOCKED_WARRANTY_AMOUNT -= _settings.CDT_PER_QUESTION;
                validator.WARRANTY_AMOUNT += _settings.CDT_PER_QUESTION;
                validator.PARTICICATIONS.push(Participation(ask.ID, validatorRewards, 0));
                ask.REWARD_WALLET_AMOUNT -= validatorRewards;
            }

            if (guaranteeToBurn > 0) {
                require(_cdtToken.burn(guaranteeToBurn) == true, "Error burn");
                _statistics.TOTAL_CDT_BURNT += guaranteeToBurn;
            }
        } else {
            ask.SCORE = 0;
            ask.STATUS = 4;
            for (uint i = 0; i < ask.PARTICIPATORS.length; i++) {
                Validator storage validator = _validators[ask.PARTICIPATORS[i]];
                
                validator.WARRANTY_AMOUNT += ask.CDT_PER_QUESTION;
                validator.LOCKED_WARRANTY_AMOUNT -= ask.CDT_PER_QUESTION;
            }
            require(_cdtToken.transfer(ask.INITIATOR, ask.REWARD_WALLET_AMOUNT) == true, "Error transfer");
            ask.REWARD_AMOUNT = 0;
        }

        emit UpdateVerification(ask.ID, ask.INITIATOR);
    }

    function claimRewards() public {
        Validator storage validator = _validators[msg.sender];

        require(validator.AMOUNT > 0, "Insufficient balance");
        require(_cdtToken.transfer(validator.WALLET, validator.AMOUNT) == true, "Error transfer");
        validator.AMOUNT = 0;
    }

    function withdrawAll() public {
        Validator storage validator = _validators[msg.sender];
        uint256 amount = validator.AMOUNT + validator.WARRANTY_AMOUNT;

        require(amount > 0, "Insufficient balance");
        require(_cdtToken.transfer(validator.WALLET, amount) == true, "Error transfer");
        validator.AMOUNT = 0;
        validator.WARRANTY_AMOUNT = 0;
    }

    // CheckDot Settings
    function setCdtPerQuestion(uint256 _amount) public onlyOwner {
        _settings.CDT_PER_QUESTION = _amount;
    }

    function setMaxCap(uint256 _value) public onlyOwner {
        _settings.MAX_CAP = _value;
    }

    function setMinCap(uint256 _value) public onlyOwner {
        _settings.MIN_CAP = _value;
    }

    function getQuestion(uint256 id) public view onlyOwner returns (QuestionWithAnswer memory) {
        return _questions[id];
    }

    function setQuestion(uint256 id, string calldata question, string[] calldata answers, string calldata answer) public onlyOwner {
        QuestionWithAnswer storage questionWithAnswer = _questions[id];
        
        questionWithAnswer.ID = id;
        questionWithAnswer.QUESTION = question;
        for (uint256 i = 0; i < answers.length; i++) {
            questionWithAnswer.ANSWERS.push(answers[i]);
        }
        questionWithAnswer.ANSWER = answer;
    }

    function claimFees() public onlyOwner {
        require(_checkDotCollectedFeesAmount > 0, "Empty");
        require(_cdtToken.transfer(_owner, _checkDotCollectedFeesAmount) == true, "Error transfer");
        _checkDotCollectedFeesAmount = 0;
    }
}