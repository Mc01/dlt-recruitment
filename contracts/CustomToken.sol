// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @dev Extension of {ERC20} that adds staking mechanism.
 *
 * Staking should allow any token holder to temporarily lock-in their funds in the contract 
 * by calling method “stake”. To withdraw staked tokens, their owner should be able to use “unstake”
 * method to do so. To receive reward for staking, the method “reward” should be used. 
 * Annual interest rate is hardcoded and set to 10%.
 *
 */
contract CustomToken is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;

    uint256 internal _minTotalSupply;
    uint256 internal _maxTotalSupply;
    uint256 internal _stakeStartTime;
    uint256 internal _stakeMinAge;
    uint256 internal _stakeMaxAge;
    uint256 internal _maxInterestRate;
    uint256 internal _stakeMinAmount;
    uint256 internal _stakePrecision;

    // Structs are not fully supported by upgrades
    // https://github.com/OpenZeppelin/openzeppelin-upgrades/issues/95
    mapping(address => uint256[]) internal _stakesAmount;
    mapping(address => uint64[]) internal _stakesTime;

    function initialize(
        uint256 minTotalSupply, 
        uint256 maxTotalSupply, 
        uint64 stakeMinAge, 
        uint64 stakeMaxAge,
        uint8 stakePrecision
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        _minTotalSupply = minTotalSupply;
        _maxTotalSupply = maxTotalSupply;
        _mint(_msgSender(), minTotalSupply);
        _stakePrecision = uint256(stakePrecision);

        _stakeStartTime = block.timestamp;
        _stakeMinAge = uint256(stakeMinAge);
        _stakeMaxAge = uint256(stakeMaxAge);

        _maxInterestRate = uint256(10**17); // 10% annual interest
        _stakeMinAmount = uint256(10**18);  // min stake of 1 token
    }

    function stakeOf(
        address account
    ) public view returns (uint256) {
        if (_stakesAmount[account].length <= 0) return 0;
        uint256 stake = 0;

        for (uint i = 0; i < _stakesAmount[account].length; i++) {
            stake = stake.add(uint256(_stakesAmount[account][i]));
        }
        return stake;
    }

    /*
     *
     * nonReentrant might not be needed
     * but in case of Upgradeable contracts 
     * it is good convention for public non-view methods
     *
     */

    function stakeAll() public 
    nonReentrant returns (bool) {
        _stake(
            _msgSender(), 
            balanceOf(_msgSender())
        );
        return true;
    }

    function unstakeAll() public
    nonReentrant returns (bool) {
        _unstake(_msgSender());
        return true;
    }

    function reward() public
    nonReentrant returns (bool) {
        _reward(_msgSender());
        return true;
    }

    function _stake(address sender, uint256 amount) internal {
        require(
            balanceOf(sender) >= amount,
            "Sender does not have enough funds"
        );

        // Decrease balance
        _decreaseBalance(sender, amount);
        
        // Update storage
        _stakesAmount[sender].push(amount);
        _stakesTime[sender].push(uint64(block.timestamp));
    }

    function _unstake(address sender) internal {
        require(
            _stakesAmount[sender].length > 0,
            "User does not have staked funds"
        );
        
        // Calculate cumulative amount
        uint256 cumulativeAmount;
        for (uint i = 0; i < _stakesAmount[sender].length; i++) {
            cumulativeAmount = cumulativeAmount.add(_stakesAmount[sender][i]);
        }

        // Clear storage
        delete _stakesAmount[sender];
        delete _stakesTime[sender];

        // Increase balance
        _increaseBalance(sender, cumulativeAmount);
    }

    function _reward(address _address) internal {
        require(
            _stakesAmount[_address].length > 0,
            "User does not have staked funds"
        );

        // Get reward
        uint256 rewarded = _getProofOfStakeReward(_address);

        // Increase balance
        _increaseBalance(_address, rewarded);

        // TODO: Set stake as withdrawn for this year
        // To do this optimally I'm leaving suggested change
        // In comment in _getCoinAge() method
    }

    function _getProofOfStakeReward(address _address) internal view returns (uint256) {
        require(
            (block.timestamp >= _stakeStartTime) && (_stakeStartTime > 0),
            "Stake start time should be greater than 0 and less or equal to block.timestamp"
        );

        uint256 _now = block.timestamp;
        uint256 _coinAge = _getCoinAge(_address, _now);
        if (_coinAge <= 0) return 0;

        uint256 interest = _getAnnualInterest();
        uint256 rewarded = (_coinAge.mul(interest)).div(uint256(365).mul(10**_stakePrecision));

        return rewarded;
    }

    function _getCoinAge(address _address, uint256 _now) internal view returns (uint256) {
        if (_stakesTime[_address].length <= 0) return 0;
        uint256 _coinAge = 0;

        for (uint i = 0; i < _stakesTime[_address].length; i++) {
            if (_now < uint256(_stakesTime[_address][i]).add(_stakeMinAge)) continue;

            uint256 nCoinSeconds = _now.sub(uint256(_stakesTime[_address][i]));
            if (nCoinSeconds > _stakeMaxAge) nCoinSeconds = _stakeMaxAge;

            _coinAge = _coinAge.add(uint256(_stakesAmount[_address][i]).mul(nCoinSeconds.div(1 days)));

            // TODO: Suggestion
            // To mark stake as rewarded 
            // I would set _stakesTime[_address][i] to block.timestamp
            // During iteration in this method
            // To avoid another loop after increasing balance with reward
        }

        return _coinAge;
    }

    function _getAnnualInterest() internal view returns(uint256) {
        return _maxInterestRate;
    }

    function _increaseBalance(address account, uint256 amount) internal {
        // Not sure if this is the goal of max total supply
        require(
            uint256(totalSupply()).add(amount) <= _maxTotalSupply,
            "Supply cannot exceed max limit!"
        );
        _mint(account, amount);
    }

    function _decreaseBalance(address account, uint256 amount) internal {
        // Not sure if this is the goal of min total supply
        require(
            uint256(totalSupply()).sub(amount) >= _minTotalSupply,
            "Supply cannot exceed min limit!"
        );
        _burn(account, amount);
    }
}
