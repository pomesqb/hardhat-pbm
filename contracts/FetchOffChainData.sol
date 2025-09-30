// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract FetchOffChainData is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    uint64 public subscriptionId;

    struct PBMRequestMeta {
        address custodian;
        uint256 amount;
        string transactionId;
        address logicContract;
    }

    struct Metadata {
        string description;
        uint256 settlementTimestamp;
        uint256 originExchangeRate;
    }

    struct ComplexData {
        uint256 id;
        Metadata metadata;
    }

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    string[] public s_stringArrResponse;

    mapping(bytes32 => PBMRequestMeta) public pbmRequests;
    mapping(bytes32 => uint256) public settlementTimestamps;
    mapping(bytes32 => uint256) public originExchangeRates;

    error UnexpectedRequestID(bytes32 requestId);

    event Response(
        bytes32 indexed requestId,
        uint256 settlementTimestamp,
        uint256 originExchangeRate,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    // Fetch data from the Web API.
    string source =
        "const transactionId = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `https://swapi.info/api/people/${transactionId}/`"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "const complexData = {"
        "id: 1,"
        "metadata: {"
        "description: 'memo',"
        "settlementTimestamp: 123456789,"
        "originExchangeRate: 31450000"
        "}"
        "};"
        "const types = ['tuple(uint256 id, tuple(string description, uint256 settlementTimestamp, uint256 originExchangeRate) metadata)']"
        "const encodedData = abiCoder.encode(types, [complexData])"
        "return ethers.getBytes(encodedData);";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    constructor(
        uint64 _subscriptionId
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        subscriptionId = _subscriptionId;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param transactionId The transaction ID to fetch data for
     * @param amount The amount associated with the request
     * @param custodian The address of the custodian
     * @return requestId The ID of the request
     */
    function sendRequest(
        string calldata transactionId,
        uint256 amount,
        address custodian
    ) external returns (bytes32) {
        string[] memory args = new string[](1);
        args[0] = transactionId;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        req.setArgs(args);

        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        s_lastRequestId = requestId;

        pbmRequests[requestId] = PBMRequestMeta({
            custodian: custodian,
            amount: amount,
            transactionId: transactionId,
            logicContract: msg.sender
        });

        return requestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }

        s_lastResponse = response;
        s_lastError = err;

        if (response.length > 0) {
            ComplexData memory data = abi.decode(response, (ComplexData));
            settlementTimestamps[requestId] = data.metadata.settlementTimestamp;
            originExchangeRates[requestId] = data.metadata.originExchangeRate;
        }

        emit Response(
            requestId,
            settlementTimestamps[requestId],
            originExchangeRates[requestId],
            s_lastResponse,
            s_lastError
        );
    }
}
