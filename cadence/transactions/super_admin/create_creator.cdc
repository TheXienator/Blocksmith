import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is for the superDdmin to create a new creator
// and store it in the blocksmith smart contract

transaction() {
    
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
        
        // Create a creator
        self.superAdminRef.createCreator()
    }

    post {
        
        Blocksmith.getBlueprints(creatorID: self.currCreatorID) != nil:
            "Could not create the a new creator"
    }
}