pragma solidity ^0.5.2;

import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import { WithdrawManager } from "../root/withdrawManager/WithdrawManager.sol";


contract Registry is Ownable {
  // @todo hardcode constants
  bytes32 constant private WETH_TOKEN = keccak256("wethToken");
  bytes32 constant private DEPOSIT_MANAGER = keccak256("depositManager");
  bytes32 constant private STAKE_MANAGER = keccak256("stakeManager");
  bytes32 constant private WITHDRAW_MANAGER = keccak256("withdrawManager");
  bytes32 constant private CHILD_CHAIN_CONTRACT = keccak256("childChainContract");
  bytes constant public networkId = "\x0d";

  mapping(bytes32 => address) contractMap;
  mapping(address => address) public rootToChildToken;
  mapping(address => address) public childToRootToken;
  mapping(address => bool) public proofValidatorContracts;
  // @todo we can think of one function from the registry which returns both (childToken,isERC721) if we are using it frequently together.
  mapping(address => bool) public isERC721;

  event TokenMapped(address indexed rootToken, address indexed childToken);
  event ProofValidatorAdded(address indexed validator, address indexed from);
  event ProofValidatorRemoved(address indexed validator, address indexed from);
  event ContractMapUpdated(
   bytes32 indexed key,
   address indexed previousContract,
   address indexed newContract
  );

  function updateContractMap(bytes32 _key, address _address)
    external
    onlyOwner
  {
    emit ContractMapUpdated(_key, contractMap[_key], _address);
    contractMap[_key] = _address;
  }

  /**
   * @dev Map root token to child token
   * @param _rootToken Token address on the root chain
   * @param _childToken Token address on the child chain
   * @param _isERC721 Is the token being mapped ERC721
   */
  function mapToken(address _rootToken, address _childToken, bool _isERC721)
    external
    onlyOwner
  {
    require(
      _rootToken != address(0x0) && _childToken != address(0x0),
      "INVALID_TOKEN_ADDRESS"
    );
    require(
      !isTokenMapped(_rootToken),
      "TOKEN_ALREADY_MAPPED"
    );
    rootToChildToken[_rootToken] = _childToken;
    childToRootToken[_childToken] = _rootToken;
    isERC721[_rootToken] = _isERC721;
    WithdrawManager(contractMap[WITHDRAW_MANAGER]).createExitQueue(_rootToken);
    emit TokenMapped(_rootToken, _childToken);
  }

  function addProofValidator(address _validator) public onlyOwner {
    require(_validator != address(0) && proofValidatorContracts[_validator] != true);
    emit ProofValidatorAdded(_validator, msg.sender);
    proofValidatorContracts[_validator] = true;
  }

  function removeProofValidator(address _validator) public onlyOwner {
    require(proofValidatorContracts[_validator] == true);
    emit ProofValidatorRemoved(_validator, msg.sender);
    delete proofValidatorContracts[_validator];
  }

  function getWethTokenAddress() public view returns(address) {
    return contractMap[WETH_TOKEN];
  }

  function getDepositManagerAddress() public view returns(address) {
    return contractMap[DEPOSIT_MANAGER];
  }

  function getStakeManagerAddress() public view returns(address) {
    return contractMap[STAKE_MANAGER];
  }

  function getWithdrawManagerAddress() public view returns(address) {
    return contractMap[WITHDRAW_MANAGER];
  }

  function getChildChainContract() public view returns(address) {
    return contractMap[CHILD_CHAIN_CONTRACT];
  }

  function isTokenMapped(address _token) public view returns (bool) {
    return rootToChildToken[_token] != address(0x0);
  }
}
