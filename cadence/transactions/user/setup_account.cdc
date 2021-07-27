import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction configures an account to hold Creations and Admin access

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection resource
        if signer.borrow<&Blocksmith.Collection>(from: Blocksmith.CollectionStoragePath) == nil {
            // create a new empty collection and save it
            let collection <- Blocksmith.createEmptyCollection()
            signer.save(<-collection, to: Blocksmith.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&Blocksmith.Collection{NonFungibleToken.CollectionPublic, Blocksmith.CreationCollectionPublic}>(Blocksmith.CollectionPublicPath, target: Blocksmith.CollectionStoragePath)
        }
        // if the account doesn't already have an admin resource
        if signer.borrow<&Blocksmith.Admin>(from: Blocksmith.AdminStoragePath) == nil {
            // create a new empty admin and save it
            let admin <- Blocksmith.createEmptyAdmin()
            signer.save(<-admin, to: Blocksmith.AdminStoragePath)

            // create a public capability for the collection
            signer.link<&Blocksmith.Admin{Blocksmith.AdminPublic}>(Blocksmith.AdminPublicPath, target: Blocksmith.AdminStoragePath)
        }
    }
}
