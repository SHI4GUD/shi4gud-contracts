// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "./Ktv2.sol";

contract Ktv2Factory {
    event Created(address created);
    Ktv2[] public created;

    function create(address _burnDest,
                    address _token,
                    address payable _dest,
                    address _pool,
                    address _ocPrcAddr,
                    address _tp,
                    bool _v2) external {

        Ktv2 newKt = new Ktv2(_burnDest, _token, _dest, _pool, _ocPrcAddr, _tp, _v2);
        newKt.transferOwnership(msg.sender);

        created.push(newKt);
        emit Created(address(newKt));
    }

    function count() public view returns (uint) {
        return created.length;
    }
}