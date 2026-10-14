@api-key-auth
Feature: API key authentication policy
  As an API developer
  I want the api-key-auth policy to authenticate every request with a valid, API-scoped key
  So that unauthenticated or mis-authenticated traffic never reaches the backend

  Background:
    Given the first gateway is running
    And I authenticate using basic auth as "admin"
    And I resolve the "capture" service URL at "" and store it as "captureUpstream"

  # Group 01 - Core accept/reject
  @aka-g01 @aka-01
  Scenario: A request with a valid API key is authenticated and forwarded to the backend
    Given I generate a unique value from "aka-s01" and store it as "akaApi"
    And I generate a unique API context from "/aka-s01" and store it as "akaCtx"
    When I create API from "resources/templates/rest-api.yaml" with values:
      | apiVersion             | ${CTX:gatewaySpecVersion} |
      | name                   | ${CTX:akaApi}             |
      | spec.displayName       | ${CTX:akaApi}             |
      | spec.version           | v1.0                      |
      | spec.context           | ${CTX:akaCtx}             |
      | spec.upstream.main.url | ${CTX:captureUpstream}    |
      | spec.operations        | [{"method":"GET","path":"/s01/probe","policies":[{"name":"api-key-auth","version":"v1","params":{"key":"Authorization","in":"header"}}]}] |
    Then the resource creation response should indicate successful deployment
    And I send a "GET" request to "${CTX:akaCtx}/s01/probe" until status 401
    When I send a "POST" request to the "gateway-controller" service at "/rest-apis/${CTX:akaApi}/api-keys" with body:
      """
      {"name":"key-one"}
      """
    Then the response status should be 201
    And I store the JSON response field "apiKey.apiKey" as "akaKey"
    And I set header "Authorization" to "Bearer ${CTX:akaKey}"
    And I send a "GET" request to "${CTX:akaCtx}/s01/probe" until status 200
    When I send a "GET" request to "${CTX:akaCtx}/s01/probe"
    Then the response status code should be 200
    And the JSON response field "path" should be "/s01/probe"
    And the response should not contain echoed header "Authorization"
    When I send a "GET" request to the "capture" service at "/test/captured?path=/s01/probe" until status 200
    Then the response body should contain "/s01/probe"
    When I clear all headers
    And I authenticate using basic auth as "admin"
    And I delete the API "${CTX:akaApi}"
    Then the response should be successful
    And I send a "GET" request to "${CTX:akaCtx}/s01/probe" until status 404
