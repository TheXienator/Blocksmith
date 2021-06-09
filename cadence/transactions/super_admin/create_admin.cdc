import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction creates a new admin struct 
// and stores gives it to an authenticated user

// Parameters:
//
// creatorIDs: A list of all the creators this admin can control

transaction(creatorIDs: [UInt32]) {

    prepare(superAdminAcct: AuthAccount, newAdminAcct: AuthAccount) {

        // borrow a reference to the admin resource
        let superAdminRef = superAdminAcct.borrow<&Blocksmith.SuperAdmin>(from: Blocksmith.SuperAdminStoragePath)
            ?? panic("No super admin resource in storage")
        
        let creatorAccess: {UInt32: Bool} = {}

        for creatorID in creatorIDs {
            creatorAccess[creatorID] = true
        }
        
        newAdminAcct.save<@Blocksmith.Admin>(<- superAdminRef.createNewAdmin(creatorAccess: creatorAccess), to: Blocksmith.AdminStoragePath)
    }
}