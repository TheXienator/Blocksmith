import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction is for retiring a blueprint from a set, which
// makes it so that blueprints can no longer be minted from that edition

// Parameters:
// 
// creatorID: the ID the creator where the blueprints and the sets are part of
// setID: the ID of the set to which multiple blueprints are added
// blueprintID: the ID of the blueprint to be retired

transaction(creatorID: UInt32, setID: UInt32, blueprintID: UInt32) {
    
    // local variable for storing the reference to the admin resource
    let adminRef: &Blocksmith.Admin

    prepare(acct: AuthAccount) {

        // borrow a reference to the Admin resource in storage
        self.adminRef = acct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")
    }

    execute {

        // borrow a reference to the specified set
        let setRef = self.adminRef.borrowSet(creatorID: creatorID, setID: setID)

        // retire the blueprint
        setRef.retireBlueprint(blueprintID: blueprintID)
    }

    post {
        
        self.adminRef.borrowSet(creatorID: creatorID, setID: setID).retired[blueprintID]!: 
            "blueprint is not retired"
    }
}