pragma solidity ^0.4.23;

import "../lib/Merkle.sol";
import "../lib/MerklePatriciaProof.sol";
import "../lib/RLP.sol";
import "../lib/Common.sol";
import "../lib/RLPEncode.sol";
import '../RootChainInterface.sol';
import './Lockable.sol';


/**
 * @title RootChainValidator
 */
contract RootChainValidator is Lockable {
  using Merkle for bytes32;
  using RLP for bytes;
  using RLP for RLP.RLPItem;
  using RLP for RLP.Iterator;

  RootChainInterface public rootChain;

  // Rootchain changed
  event RootChainChanged(
    address indexed previousRootChain,
    address indexed newRootChain
  );

  /**
   * @dev Allows the current owner to change root chain address.
   * @param newRootChain The address to new rootchain.
   */
  function changeRootChain(address newRootChain) external onlyOwner {
    require(newRootChain != address(0));
    emit RootChainChanged(rootChain, newRootChain);
    rootChain = RootChainInterface(newRootChain);
  }

  // validate transaction
  function validateTxExistence(
    uint256 headerNumber,
    bytes headerProof,

    uint256 blockNumber,
    uint256 blockTime,

    bytes32 txRoot,
    bytes32 receiptRoot,
    bytes txBytes,
    bytes txProof,
    bytes path
  ) public view returns (bool) {
    // get header information
    var (headerRoot, start,,) = rootChain.getHeaderBlock(headerNumber);

    // check if tx's block is included in header and tx is in block
    return keccak256(blockNumber, blockTime, txRoot, receiptRoot)
      .checkMembership(blockNumber - start, headerRoot, headerProof)
    && MerklePatriciaProof.verify(txBytes, path, txProof, txRoot);
  }

  // validate transaction
  function validateTx(
    uint256 headerNumber,
    bytes headerProof,

    uint256 blockNumber,
    uint256 blockTime,

    bytes32 txRoot,
    bytes32 receiptRoot,
    bytes txBytes,
    bytes txProof,
    bytes path,

    address sender
  ) public view returns (bool) {
    if (
      validateTxExistence(
        headerNumber,
        headerProof,
        blockNumber,
        blockTime,
        txRoot,
        receiptRoot,
        txBytes,
        txProof,
        path
      )
    ) {
      return false;
    }

    // check tx
    RLP.RLPItem[] memory txList = txBytes.toRLPItem().toList();
    if (txList.length != 9) {
      return false;
    }

    // raw tx
    bytes[] memory rawTx = new bytes[](9);
    for (uint8 i = 0; i <= 5; i++) {
      rawTx[i] = txList[i].toData();
    }
    rawTx[4] = hex"";
    rawTx[6] = rootChain.networkId();
    rawTx[7] = hex"";
    rawTx[8] = hex"";

    // recover sender from v, r and s
    if (
      ecrecover(
        keccak256(RLPEncode.encodeList(rawTx)),
        Common.getV(txList[6].toData(), Common.toUint8(rootChain.networkId())),
        txList[7].toBytes32(),
        txList[8].toBytes32()
      ) != sender
    ) {
      return false;
    }

    return true;
  }
}