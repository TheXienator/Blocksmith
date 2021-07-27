import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Blocksmith from "../../contracts/Blocksmith.cdc"

// This is for admin accounts to extend their admin capability to another account
//
// recipient: The Flow address of the account to receive the admin access.
// creatorID: The id of the creator access to be granted

transaction(recipient: Address, creatorID: UInt32) {

 // Local variable for the Blocksmith Admin object
    let adminRef: &Blocksmith.Admin
    let tempAdmin: @Blocksmith.Admin

    prepare(adminAcct: AuthAccount) {
        // borrow a reference to the admin resource
        self.adminRef = adminAcct.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath)
            ?? panic("No admin resource in storage")

        self.tempAdmin <- self.adminRef.createNewAdmin(creatorAccess: {creatorID: true})
    }

    execute {
        let recipientAccount = getAccount(recipient)
        let receiverRef = recipientAccount.getCapability(Blocksmith.AdminPublicPath).borrow<&{Blocksmith.AdminPublic}>()!

        let temp <- receiverRef.extendCreatorAccess(creatorID: creatorID, extender: <- self.tempAdmin)

        destroy temp
    }
}