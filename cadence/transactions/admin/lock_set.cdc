import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction locks a set so that new blueprints can no longer be added to it

// Parameters:
//
// creatorID: the ID of the creator the sets are from
// setID: the ID of the set to be locked

transaction(creatorID: UInt32, setID: UInt32) {

    // local variable for the admin resource
    let adminRef: &Blocksmith.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {
        // borrow a reference to the Set
        let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: setID)

        // lock the set permanently
        setRef.lock()
    }

    post {
        
        Blocksmith.isSetLocked(creatorID: creatorID, setID: setID)!:
            "Set did not lock"
    }
}