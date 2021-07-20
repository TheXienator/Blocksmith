import Blocksmith from "../../contracts/Blocksmith.cdc"

// This is for SuperAdmins to give other accounts creatorAccess
//
// recipient: The Flow address of the account to receive the admin access.
// creatorID: The id of the creator access to be granted

transaction(recipient: Address, creatorID: UInt32) {

 // Local variable for the Blocksmith Admin object
    let superAdminRef: &Blocksmith.SuperAdmin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin resource
        self.superAdminRef = acct.borrow<&Blocksmith.SuperAdmin>(from: Blocksmith.SuperAdminStoragePath)
            ?? panic("No super admin resource in storage")
    }

    execute {
        let recipientAccount = getAccount(recipient)
        let receiverRef = recipientAccount.getCapability(Blocksmith.AdminPublicPath).borrow<&{Blocksmith.AdminPublic}>()!

        self.superAdminRef.addCreatorIDsToAdmin(creatorIDs: [creatorID], adminRef: receiverRef)
    }
}