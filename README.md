## Lyra V2 Account Abstraction

<div align="center">
  <p align='center'>
    <br>
    <img src='./imgs/lyrav2.png' alt='lyra' width="600" />
    <h5 align="center"> Account Abstraction is here! </h6>
</p> 
</div>

This repo contains all contracts that help Lyra v2 achieve Account Abstraction experience. 
More specifically, for L1 to L2 gasless deposits, we use Gelato relayer; for all L2 transactions, we adopt ERC4337, with our own Paymaster and [LightAccount](!https://github.com/alchemyplatform/light-account/blob/main/src/LightAccount.sol) from Alchemy. 

## Usage

### Build

```shell
$ forge build
```

### Test

We have a few fork tests for deposit and withdraw helpers. You can run them on Mainnet / Lyra chain with commands below:

```shell
# tests on Lyra chain
$ forge test --match-contract FORK_LYRA_ --fork-url https://rpc.lyra.finance

# tests on Mainnet 
$ forge test --match-contract FORK_MAINNET_ --fork-url <mainnet rpc>
```

### Using the contracts

Go see [this repo](https://github.com/antoncoding/lyra-aa-example) for examples


# Deployments

## Gasless Deposit Forwarders
Gasless forwarders are used to make sure users only with ERC20 can deposit to Lyra

### ETH
| Network | USDC Selfpaying Forwarder | USDC Sponsored Forwarder  |
| -------- | -------- | --- |
| Ethereum Mainnet     | [0x00efac83a3168568e258ab1ec85e85c10cbaf74e](https://etherscan.io/address/0x00efac83a3168568e258ab1ec85e85c10cbaf74e#code)    |  [0xf0372da389db728a3173a7b91c5cb4437a6319ea](https://etherscan.io/address/0xf0372da389db728a3173a7b91c5cb4437a6319ea)|

* On Ethereum Mainnet, only USDC supports gasless deposit.
* We use a differnet forwarder here that only work with USDC (`receiveWithAuth`) to minimize gas cost.

### Arbitrum

| Network | SelfPaying Permit Forwarder | Sponsored Permit Forwarder  |
| -------- | -------- | --- |
| Arbitrum     | [0x00eFAc83a3168568e258ab1Ec85E85C10cBAf74E](https://arbiscan.io/address/0x00eFAc83a3168568e258ab1Ec85E85C10cBAf74E)     | [0xC3621651c550F3c1BC146ffAe0975a566423Da17](https://arbiscan.io/address/0xC3621651c550F3c1BC146ffAe0975a566423Da17) |
| Arbitrum Sepolia | - | [0xE3436F0F982fbbAf88f28DACE9b36a85c97aECdE](https://sepolia.arbiscan.io/address/0xE3436F0F982fbbAf88f28DACE9b36a85c97aECdE) |

* On Arbitrum, all ERC20s can be gasless (with `permit`)

 ### Optimism
| Network | SelfPaying Permit Forwarder | Sponsored Permit Forwarder  |
| -------- | -------- | --- |
| Optimism     |   [0xAa7Dd6fa6B604b776BCE03Af6ED717c00E66538E](https://optimistic.etherscan.io/address/0xAa7Dd6fa6B604b776BCE03Af6ED717c00E66538E#code)   | [0x062B67001A6dd9FC6Aa1CFB9c246AcfFC4BfAdC5](https://optimistic.etherscan.io/address/0x062B67001A6dd9FC6Aa1CFB9c246AcfFC4BfAdC5#code) |
| Optimism Sepolia | - | [0x1480Cfe30213b134f757757d328949AAe406eA33](https://sepolia-optimistic.etherscan.io/address/0x1480Cfe30213b134f757757d328949AAe406eA33#code) |


* On Optimism, only USDC has `permit` now, but other ERC20s can potentially use these contracts to achieve gasless deposit if they have permit.


## Deposit Helper 

### `LyraDepositWrapper`

Help wrapping ETH and deposit with socket vault in one go. Can also be used with ERC20 deposits to calculate L2 address


### Mainnet
| Network | Address | 
| -------- | -------- | 
| Ethereum     | [0x18a0f3F937DD0FA150d152375aE5A4E941d1527b](https://etherscan.io/address/0x18a0f3f937dd0fa150d152375ae5a4e941d1527b#code)    |
| Optimism     | [0xC65005131Cfdf06622b99E8E17f72Cf694b586cC](https://optimistic.etherscan.io/address/0xC65005131Cfdf06622b99E8E17f72Cf694b586cC#code)     |
| Arbitrum     |  [0x076BB6117750e80AD570D98891B68da86C203A88](https://arbiscan.io/address/0x076BB6117750e80AD570D98891B68da86C203A88#readContract)    |

### Testnet
| Network | Address | 
| -------- | -------- | 
| Sepolia     | [0x46e75b6983126896227a5717f2484efb04a0c151](https://sepolia.etherscan.io/address/0x46e75b6983126896227a5717f2484efb04a0c151#readContract)     |
| Op-Sepolia     | [0x3E7DEc059a3692c184BF0D0AC3d9Af7570DF6A3c](https://sepolia-optimistic.etherscan.io/address/0x3E7DEc059a3692c184BF0D0AC3d9Af7570DF6A3c#code)  |
| Arbi-Sepolia     | [0x5708bDE1c5e49b62cfd46D07b5cd3c898930Ef23](https://sepolia.arbiscan.io/address/0x5708bDE1c5e49b62cfd46D07b5cd3c898930Ef23#readContract)     |



## Withdraw Helper 

### `WithdrawHelperV2`

withdraw ERC20s from Lyra Chain back to Mainnet / L2s, paid socket fee in token.

| Network | Address | 
| -------- | -------- | 
| Lyra     |   [0x0E4e5779F633F823d007f3C27fa6feFb22B45316](https://explorer.lyra.finance/address/0x0E4e5779F633F823d007f3C27fa6feFb22B45316)   |
| Lyra Testnet    | [0xD7080B2399B88c3520F8F793f4758D0C6ccDf48a](https://explorerl2new-prod-testnet-0eakp60405.t.conduit.xyz/address/0xD7080B2399B88c3520F8F793f4758D0C6ccDf48a)  |
