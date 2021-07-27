import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction allows an admin to increment the series of a creator
transaction(creatorID: UInt32) {

    // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {
        self.adminRef.startNewSeries(creatorID: creatorID)
    }
}
