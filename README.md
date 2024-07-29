# Foundry Project

This project demonstrates the deployment and testing of a Solidity smart contract using Foundry.

## Prerequisites

- Ensure you have Foundry installed. If not, you can install it by following the instructions [here](https://getfoundry.sh/).

## Getting Started

1. **Clone the Repository:**

    ```bash
    git clone farman13/StakeNFT
    ```

2. **Build the Project:**

    ```bash
    forge build
    ```

3. **Download OpenZeppelin Contracts Dependencies:**

    ```bash
    forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
    ```


4. **Load Environment Variables:**

    ```bash
    set -o allexport
    source .env
    set +o allexport
    ```

5. **Verify Environment Variables:**

    ```bash
    echo $PRIVATE_KEY
    echo $SEPOLIA_RPC_URL
    ```

6. **Deploy the Contract to Sepolia Network:**

    ```bash
    forge script script/DeployStakeNFT.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
    ```

7. **Run Tests:**

    ```bash
    forge test
    ```

## Project Structure

- `src/` - Contains the Solidity smart contract source files.
- `script/` - Contains the deployment scripts.
- `test/` - Contains the test files.


## License

This project is licensed under the MIT License.

