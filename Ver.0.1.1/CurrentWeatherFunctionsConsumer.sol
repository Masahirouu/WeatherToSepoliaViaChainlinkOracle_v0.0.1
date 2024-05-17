// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// import {FunctionsClient} from "@chainlink/contracts@1.1.0/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// import {ConfirmedOwner} from "@chainlink/contracts@1.1.0/src/v0.8/shared/access/ConfirmedOwner.sol";
// import {FunctionsRequest} from "@chainlink/contracts@1.1.0/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract CurrentWeatherFunctionsConsumer is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string currentWeather,
        bytes response,
        bytes err
    );

    // Router address
    // For Fuji
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    // For Sepolia
    // address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    string source =
        "const lat = String(args[0]);"
        "const lng = String(args[1]);"
        "const apiKey = args[2];"

        "const apiResponse = await Functions.makeHttpRequest({"
        "  url: `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lng}&appid=${apiKey}&units=metric`"
        "});"

        // "const temperature = apiResponse.data.base;"
        // "const temperature = apiResponse.data.main.temp.toString();"
        // "const result = temperature;"
        // "return Functions.encodeString(result);"

        "const lat_ = apiResponse.data.coord.lat;"
        "const lon_ = apiResponse.data.coord.lon;"
        "const description_ = apiResponse.data.weather[0].description;"
        "const temperature_ = apiResponse.data.main.temp;"
        "const result = {"
            "latitude: lat_,"
            "longitude: lon_,"
            "description: description_,"
            "temperature: temperature_"
        "};"
        "return Functions.encodeString(JSON.stringify(result));";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded
    // For Fuji
    bytes32 donID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    // For Sepolia
    // bytes32 donID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // State variable to store the returned currentWeather information
    string public currentWeather;

    // My subscription ID.
    uint64 public subscriptionId;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(uint64 functionsSubscriptionId) FunctionsClient(router) {
              subscriptionId = functionsSubscriptionId;
    }

    /**
     * @notice Sends an HTTP request for currentWeather information
     * @return requestId The ID of the request
     */
    function sendRequest(
        // uint64 subscriptionId,
        string[] calldata args
    ) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
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
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        currentWeather = string(response);
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, currentWeather, s_lastResponse, s_lastError);
    }
}
