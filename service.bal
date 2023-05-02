import ballerina/http;
import ballerina/regex;
import ballerina/io;


//Import the SCIM module.
import ballerinax/scim;

configurable string orgName = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scope = [
    "internal_user_mgt_view",
    "internal_user_mgt_list",
    "internal_user_mgt_create",
    "internal_user_mgt_delete",
    "internal_user_mgt_update",
    "internal_user_mgt_delete",
    "internal_group_mgt_view",
    "internal_group_mgt_list",
    "internal_group_mgt_create",
    "internal_group_mgt_delete",
    "internal_group_mgt_update",
    "internal_group_mgt_delete"
];

//Create a SCIM connector configuration
scim:ConnectorConfig scimConfig = {
    orgName: orgName,
    clientId: clientId,
    clientSecret: clientSecret,
    scope: scope
};

scim:Client scimClient = check new (scimConfig);

type UserCreateRequest record {
    string password;
    string email;
    string name;
};

string salesGroupId = "5240d584-0fc4-494b-86de-24594e42bce3";
string marketingGroupId = "d580ae3f-5e26-425d-b706-e2be71c44dcd";
string defaultGroupId = "05c2c7a2-71e8-4952-b714-abfb11528013";

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function get groupUserCount() returns json|error {
        scim:GroupResource salesResponse = check scimClient->getGroup(salesGroupId);
        int salesCount = 0;
        if salesResponse.members != () {
            salesCount = (<scim:Member[]>salesResponse.members).length();
        }
        scim:GroupResource marketingResponse = check scimClient->getGroup(marketingGroupId);
        int marketingCount = 0;
        if marketingResponse.members != () {
            marketingCount = (<scim:Member[]>marketingResponse.members).length();
        }
        json output = {SalesTeamCount: salesCount, MarketingTeamCount: marketingCount};
        return output;
    }

    resource function post createUser(@http:Payload UserCreateRequest payload) returns string|error {
        
        // create user
        scim:UserCreate user = {password: payload.password};
        user.userName = string `DEFAULT/${payload.email}`;
        io:println(user.userName);
        user.name = {formatted: payload.name};
        scim:UserResource response = check scimClient->createUser(user);
        string groupId;
        // add created user to the relevant group
        string createdUser = response.id.toString();
        if regex:matches(payload.email, "[A-Za-z0-9]+@sales\\.greenApps\\.com") {
            groupId = salesGroupId;
        }
        else if regex:matches(payload.email.toString(), "[A-Za-z0-9]+@marketing\\.greenApps\\.com") {
            groupId = marketingGroupId;
        }
        else {
            groupId = defaultGroupId;
        }
        scim:GroupPatch Group = {Operations: [{op: "add", value: {members: [{"value": createdUser, "display": user.userName}]}}]};
        scim:GroupResource groupResponse = check scimClient->patchGroup(groupId, Group);
        return "User Successfully Created";
    }

    resource function post searchProfile(@http:Payload string email) returns scim:UserResource[]?|error {
        
        string userName = string `DEFAULT/${email}`;
        scim:UserSearch searchData = {filter: string `userName eq ${userName}`};
        scim:UserResponse response = check scimClient->searchUser(searchData);
        return response.Resources;
    }

    resource function delete deleteUser(string email) returns string|error {
        
        string userName = string `DEFAULT/${email}`;
        scim:UserSearch searchData = {filter: string `userName eq ${userName}`};
        scim:UserResponse response = check scimClient->searchUser(searchData);
        if response.Resources is () {return error ("User not found");}
        string deleteId = <string>(<scim:UserResource[]>response.Resources)[0].id;
        json response1 = check scimClient->deleteUser(deleteId);
        return "User deleted successfully";
    }

}
