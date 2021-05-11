// SPDX-License-Identifier: MIT

/**
 * @author          Yisi Liu
 * @contact         yisiliu@gmail.com
 * @author_time     01/06/2021
**/

pragma solidity >= 0.8.0;

import "./IQLF.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract QLF_LUCKYDRAW is IQLF {

    string private name;
    uint256 private creation_time;
    uint256 start_time;
    // in wei
    uint256 public max_gas_price;
    uint256 public min_token_amount;
    address public token_addr;
    // Chance to be selected as a lucky player
    // 0 : 100%
    // 1 : 75%
    // 2 : 50%
    // 3 : 25%
    uint8 public lucky_factor;
    address creator;
    mapping(address => bool) black_list;

    event GasPriceOver ();
    event Unlucky ();

    modifier creatorOnly {
        require(msg.sender == creator, "Not Authorized");
        _;
    }

    constructor (string memory _name,
                uint256 _start_time,
                uint256 _max_gas_price,
                uint256 _min_token_amount,
                address _token_addr,
                uint8 _lucky_factor) {
        name = _name;
        creation_time = block.timestamp;
        start_time = _start_time;
        max_gas_price = _max_gas_price;
        min_token_amount = _min_token_amount;
        token_addr = _token_addr;
        lucky_factor = _lucky_factor;
        creator = msg.sender;
    }

    function get_name() public view returns (string memory) {
        return name;
    }

    function get_creation_time() public view returns (uint256) {
        return creation_time;
    }

    function get_start_time() public view returns (uint256) {
        return start_time;
    }

    function set_start_time(uint256 _start_time) public creatorOnly {
        start_time = _start_time;
    }

    function set_max_gas_price(uint256 _max_gas_price) public creatorOnly {
        max_gas_price = _max_gas_price;
    }

    function set_min_token_amount(uint256 _min_token_amount) public creatorOnly {
        min_token_amount = _min_token_amount;
    }

    function set_lucky_factor(uint8 _lucky_factor) public creatorOnly {
        lucky_factor = _lucky_factor;
    }

    function set_token_addr(address _token_addr) public creatorOnly {
        token_addr = _token_addr;
    }

    function ifQualified(address account) public view override returns (bool qualified) {
        qualified = (IERC20(token_addr).balanceOf(account) >= min_token_amount);
    } 

    function logQualified(address account, uint256 ito_start_time) public override returns (bool qualified) {
        if (tx.gasprice > max_gas_price) {
            emit GasPriceOver();
            revert("Gas price too high");
        }

        require(IERC20(token_addr).balanceOf(account) >= min_token_amount, "Not holding enough tokens");

        if (start_time > block.timestamp || ito_start_time > block.timestamp) {
            black_list[account] = true;
            revert("Not started.");
        }
        require(black_list[account] == false, "Blacklisted");
        if (isLucky(account) == false) {
            emit Unlucky();
            emit Qualification(account, false, block.number, block.timestamp);
            revert("Not lucky enough");
        }
        emit Qualification(account, true, block.number, block.timestamp);
        qualified = true;
    } 

    function supportsInterface(bytes4 interfaceId) external override pure returns (bool) {
        return interfaceId == this.supportsInterface.selector || 
            interfaceId == (this.ifQualified.selector ^ this.logQualified.selector) ||
            interfaceId == this.get_start_time.selector;
    }

    function isLucky(address account) internal view returns (bool) {
        if (lucky_factor == 0) {
            return true;
        }
        uint256 blocknumber = block.number;
        uint256 random_block = blocknumber - 1 - uint256(
            keccak256(abi.encodePacked(blockhash(blocknumber-1), account))
        ) % 255;
        bytes32 sha = keccak256(abi.encodePacked(blockhash(random_block), account, block.coinbase, block.difficulty));
        return ((uint8(sha[0]) & 0x03) >= lucky_factor);
    }
}
