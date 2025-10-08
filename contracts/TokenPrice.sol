// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract TokenPrice {

    // This contract assumes that both tokens in the pair have 18 decimals
    uint8 constant ASSUMED_DECIMALS = 18;

    function price(address poolAddr) external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        return FullMath.mulDiv(numerator1, 10 ** ASSUMED_DECIMALS, 1 << 192);
    }

    function priceV2(address pairAddr) external view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        require(reserve0 > 0, "Reserve0 is zero");
        return FullMath.mulDiv(uint256(reserve1), 10 ** ASSUMED_DECIMALS, uint256(reserve0));
    }
}