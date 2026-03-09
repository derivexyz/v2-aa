// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MultiDistro {
    struct Batch {
        address[] targets;
        uint256[] amounts;
        uint256 total;
        bool executed;
    }

    address public immutable proposer;
    IERC20 public immutable token;

    uint256 public nextBatchId = 1;
    mapping(uint256 => Batch) public batches;

    constructor(address _proposer, address _token) {
        proposer = _proposer;
        token = IERC20(_token);
    }

    function getBatch(uint256 batchId) external view returns (Batch memory) {
        return batches[batchId];
    }

    function propose(address[] calldata targets, uint256[] calldata amounts) external {
        require(msg.sender == proposer, "Only proposer");
        require(targets.length == amounts.length, "Length mismatch");
        require(targets.length > 0, "No targets");
        uint256 total;
        Batch storage batch = batches[nextBatchId];
        for (uint256 i; i < amounts.length; i++) {
            total += amounts[i];
            batch.targets.push(targets[i]);
            batch.amounts.push(amounts[i]);
        }
        batch.total = total;
        nextBatchId++;
    }

    function execute(uint256 batchId) external {
        Batch storage batch = batches[batchId];
        require(!batch.executed, "Already executed");
        batch.executed = true;
        IERC20(token).transferFrom(msg.sender, address(this), batch.total);
        for (uint256 i; i < batch.targets.length; i++) {
            IERC20(token).transfer(batch.targets[i], batch.amounts[i]);
        }
    }
}
