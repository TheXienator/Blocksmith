import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is for the superAdmin to create a new creator
// and store it in the blocksmith smart contract and give admin access
// to the creatorAddress

transaction(creatorAddress: Address) {

    // Local variable for the Blocksmith Admin object
    let superAdminRef: &Blocksmith.SuperAdmin
    let currCreatorID: UInt32

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin resource
        self.superAdminRef = acct.borrow<&Blocksmith.SuperAdmin>(from: Blocksmith.SuperAdminStoragePath)
            ?? panic("No super admin resource in storage")

        self.currCreatorID = Blocksmith.nextCreatorID
    }

    execute {
        self.superAdminRef.createCreator(creatorAddress: creatorAddress)

        let creatorAccount = getAccount(creatorAddress)
        let creatorAdminRef = creatorAccount.getCapability(Blocksmith.AdminPublicPath).borrow<&{Blocksmith.AdminPublic}>()!

        self.superAdminRef.addCreatorIDsToAdmin(creatorIDs: [self.currCreatorID], adminRef: creatorAdminRef)
    }
    
    post {
        Blocksmith.getCreator(creatorID: self.currCreatorID) != nil:
            "Could not create the new creator"
        Blocksmith.getCreator(creatorID: self.currCreatorID)!.creatorAddress == creatorAddress:
            "Could not set the proper creatorAddress"
        Blocksmith.nextCreatorID == self.currCreatorID + UInt32(1):
            "Could not set the next creatorID"
    }
}