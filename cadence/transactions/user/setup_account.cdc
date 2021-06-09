import NonFungibleToken from "../../contracts/standard/NonFungibleToken.cdc"
import Blocksmith from "../../contracts/Blocksmith.cdc"

// This transaction configures an account to hold Creations

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&Blocksmith.Collection>(from: Blocksmith.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- Blocksmith.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: Blocksmith.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&Blocksmith.Collection{NonFungibleToken.CollectionPublic, Blocksmith.CreationCollectionPublic}>(Blocksmith.CollectionPublicPath, target: Blocksmith.CollectionStoragePath)
        }
    }
}
