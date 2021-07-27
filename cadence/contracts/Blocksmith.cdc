/*
    Description: Central Smart Contract for Blocksmith

    authors: Jason Xie jason.xie@blocksmith.so

    This smart contract contains the core functionality for Blocksmith

    It manages the data associated with all the blueprints and sets
    that are used as templates for the Creation NFTs

    The admin resource has the power to do all of the important actions
    in the smart contract. Admins can

    - create a new Blueprint that is stored in the overall contract.
    - create new Sets, which consist of a public struct and a private resource
    - add Blueprints to a Set or retire Blueprints from a Set
    - mint new creations from the blueprints linked to the Set.

    When admins want to call functions in a set,
    they call their borrowSet function to get a reference,
    which they can use to call functions. 
    
    When creations are minted, they are initialized with a CreationData struct and
    are returned by the minter.

    The contract also defines a Collection resource. This is an object that 
    every Blocksmith NFT owner will store in their account
    to manage their NFT collection.

    The creator's Blocksmith account will also have its own Creation collections
    it can use to hold its own creations that have not yet been sent to a user.

    Note: All state changing functions will panic if an invalid argument is
    provided or one of its pre-conditions or post conditions aren't met.
    Functions that don't modify state will simply return 0 or nil 
    and those cases need to be handled by the caller.
*/

import NonFungibleToken from 0x631e88ae7f1d7c20

pub contract Blocksmith: NonFungibleToken {

    // -----------------------------------------------------------------------
    // Blocksmith contract Events
    // -----------------------------------------------------------------------

    // Emitted when the Blocksmith contract is created
    pub event ContractInitialized()

    // Emitted when a new Creator is added to the contract
    pub event CreatorCreated(creatorID: UInt32, creatorAddress: Address)

    // Emitted when a new Blueprint struct is created
    pub event BlueprintCreated(creatorID: UInt32, blueprintID: UInt32, metadata: {String: String})
    // Emitted when a new series has been triggered by an admin
    pub event NewSeriesStarted(creatorID: UInt32, newCurrentSeries: UInt32)

    // Events for Set-Related actions
    //
    // Emitted when a new Set is created
    pub event SetCreated(creatorID: UInt32, setID: UInt32, series: UInt32)
    // Emitted when a new Blueprint is added to a Set
    pub event BlueprintAddedToSet(creatorID: UInt32, setID: UInt32, blueprintID: UInt32)
    // Emitted when a Blueprint is retired from a Set and cannot be used to mint
    pub event BlueprintRetiredFromSet(creatorID: UInt32, setID: UInt32, blueprintID: UInt32, numCreations: UInt32)
    // Emitted when a Set is locked, meaning Blueprints cannot be added
    pub event SetLocked(setID: UInt32)
    // Emitted when a Creation is minted from a Set
    pub event CreationMinted(
        globalCreationID: UInt64, 
        creatorID: UInt32, 
        creationID: UInt32,
        blueprintID: UInt32, 
        setID: UInt32, 
        serialNumber: UInt32
    )

    // Events for Collection-related actions
    //
    // Emitted when a creation is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)
    // Emitted when a creation is deposited into a Collection
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when a Creation is destroyed
    pub event CreationDestroyed(id: UInt64)

    // -----------------------------------------------------------------------
    // Blocksmith contract-level fields.
    // These contain actual values that are stored in the smart contract.
    // -----------------------------------------------------------------------

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let SuperAdminStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath
    pub let AdminPublicPath: PublicPath

    // The ID that is used to create Blueprints. 
    // Every time a Blueprint is created, blueprintID is assigned 
    // to the new Blueprint's ID and then is incremented by 1.
    pub var nextCreatorID: UInt32

    // The total number of Blocksmith Creation NFTs that have been created across all creators
    // Because NFTs can be destroyed, it doesn't necessarily mean that this
    // reflects the total number of NFTs in existence, just the number that
    // have been minted to date. Also used as global creation IDs for minting.
    pub var totalSupply: UInt64

    // Mapping from creatorID to creatorSets
    // creatorSets is a mapping from setID to Set Resource
    access(self) var sets: @{UInt32: {UInt32: Set}}

    // Mapping from creatorID to Creator struct
    access(self) var creators: {UInt32: Creator}

    // -----------------------------------------------------------------------
    // Blocksmith initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/BlocksmithCreationCollection
        self.CollectionPublicPath = /public/BlocksmithCreationCollection
        self.SuperAdminStoragePath = /storage/BlocksmithSuperAdmin
        self.AdminStoragePath = /storage/BlocksmithAdmin
        self.AdminPublicPath = /public/BlocksmithAdmin

        // Initialize contract fields
        self.creators = {}
        self.sets <- {}
        self.totalSupply = 0
        self.nextCreatorID = 1

        // Uncomment if we need to hard reset during testing
        // if (self.account.borrow<&Collection>(from: self.CollectionStoragePath) != nil) {
        //     destroy self.account.load<@Collection>(from: self.CollectionStoragePath)
        // }
        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: self.CollectionStoragePath)

        // Create a public capability for the Collection
        self.account.link<&{CreationCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        // Put a new Admin Resource in storage
        self.account.save<@Admin>(<- create Admin(creatorAccess: {}), to: self.AdminStoragePath)

        // Create a public capability for the Collection
        self.account.link<&{AdminPublic}>(self.AdminPublicPath, target: self.AdminStoragePath)

        // Uncomment if we need to hard reset during testing
        // if (self.account.borrow<&SuperAdmin>(from: self.SuperAdminStoragePath) != nil) {
        //     destroy self.account.load<@SuperAdmin>(from: self.SuperAdminStoragePath)
        // }
        // Put the SuperAdmin in storage
        self.account.save<@SuperAdmin>(<- create SuperAdmin(), to: self.SuperAdminStoragePath)

        emit ContractInitialized()
    }

    // -----------------------------------------------------------------------
    // Blocksmith creator-level fields.
    // Each creator manages their own 
    // -----------------------------------------------------------------------

    pub struct Creator {

        // The unique ID for the Creator
        pub let creatorID: UInt32

        // The unique wallet that is the original owner of all assets
        // created by this Creator. Will be used the address used
        // to give original creators a cut of secondary marketplaces.
        pub let creatorAddress: Address

        // Series is a concept that indicates a group of Sets through time.
        pub var currentSeries: UInt32

        // The ID that is used to create Blueprints. 
        // Every time a Blueprint is created, blueprintID is assigned to
        // the new Blueprint's ID and then is incremented by 1.
        pub var nextBlueprintID: UInt32

        // The ID that is used to create Sets. Every time a Set is created
        // setID is assigned to the new set's ID and then is incremented by 1.
        pub var nextSetID: UInt32

        // The total number of Blocksmith Creation NFTs that have been created by this Creator
        // Because NFTs can be destroyed, it doesn't necessarily mean that this
        // reflects the total number of NFTs for this Creator in existence, just the number that
        // have been minted to date. Also used as creation IDs for minting.
        pub var numCreations: UInt32

        // Metadata related to a creator that can be changed at any time
        access(self) var creatorMetadata: {String: String}

        // Variable size dictionary of Blueprint structs
        access(self) var blueprints: {UInt32: Blueprint}

        init(creatorAddress: Address) {
            // Initialize contract fields
            self.creatorID = Blocksmith.nextCreatorID
            self.creatorMetadata = {}
            self.creatorAddress = creatorAddress
            self.currentSeries = 0
            self.blueprints = {}
            self.nextBlueprintID = 1
            self.nextSetID = 1
            self.numCreations = 0

            // Increment the ID so that it isn't used again
            Blocksmith.nextCreatorID = Blocksmith.nextCreatorID + UInt32(1)

            // Setup global resources for the new creator
            Blocksmith.sets[self.creatorID] <-! {}

            emit CreatorCreated(creatorID: self.creatorID, creatorAddress: creatorAddress)
        }

        // method an admin can use at any time to update creator metadata
        pub fun updateMetadata(updatedData: {String: String}) {
            for key in updatedData.keys {
                self.creatorMetadata[key] = updatedData[key]
            }
        }

        // Helper functions for creations
        pub fun containsBlueprint(blueprintID: UInt32): Bool {
            return self.blueprints[blueprintID] != nil
        }

        pub fun canMint(blueprintID: UInt32): Bool {
            return self.containsBlueprint(blueprintID: blueprintID) && self.blueprints[blueprintID]!.canMint()
        }

        // Helper functions for incrementing
        pub fun incrementNextBlueprintID() {
            self.nextBlueprintID = self.nextBlueprintID + UInt32(1)
        }

        pub fun incrementNextSetID() {
            self.nextSetID = self.nextSetID + UInt32(1)
        }

        pub fun incrementCurrentSeries() {
            self.currentSeries = self.currentSeries + UInt32(1)
        }

        pub fun incrementCreationCount(blueprintID: UInt32) {
            pre {
                self.containsBlueprint(blueprintID: blueprintID):  "Not a valid blueprint"
            }

            self.blueprints[blueprintID]!.incrementCreationCount()
        }

        pub fun incrementNumCreations() {
            self.numCreations = self.numCreations + UInt32(1)
        }

        // Adds blueprint to creator's blueprints
        pub fun addBlueprint(blueprintID: UInt32, blueprint: Blueprint) {
            pre {
                self.blueprints[blueprintID] == nil: "Blueprint already saved"
            }

            self.blueprints[blueprintID] = blueprint
        }

        // getAllBlueprints returns all the blueprints for this Creator
        //
        // Returns: An array of all the blueprints that have been created
        pub fun getBlueprints(): [Blocksmith.Blueprint] {
            return self.blueprints.values
        }

        // getBlueprint returns an optional which is either the blueprint
        // with that id for the creator or empty if it doesn't exist
        //
        // Returns: An option the blueprint with that ID
        pub fun getBlueprint(blueprintID: UInt32): Blocksmith.Blueprint? {
            return self.blueprints[blueprintID]
        }

        // getBlueprintMetaData returns all the metadata associated with a specific Blueprint
        // 
        // Parameters: blueprintID: The id of the Blueprint that is being searched
        //
        // Returns: The metadata as a String to String mapping optional
        pub fun getBlueprintMetaData(blueprintID: UInt32): {String: String}? {
            return self.blueprints[blueprintID]?.metadata
        }

        // getBlueprintMetaDataByField returns the metadata associated with a 
        //                        specific field of the metadata
        //                        Ex: field: "Author" will return something
        //                        like "John Doe"
        // 
        // Parameters: blueprintID: The id of the Blueprint that is being searched
        //             field: The field to search for
        //
        // Returns: The metadata field as a String Optional
        pub fun getBlueprintMetaDataByField(blueprintID: UInt32, field: String): String? {
            // Don't force a revert if the blueprintID or field is invalid
            if let blueprint = self.blueprints[blueprintID] {
                return blueprint.metadata[field]
            } else {
                return nil
            }
        }
    }

    // -----------------------------------------------------------------------
    // Blocksmith contract-level Composite Type definitions
    // -----------------------------------------------------------------------
    // These are just *definitions* for Types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these Types
    // can be created by this contract that contains stored values.
    // -----------------------------------------------------------------------

    // Blueprint is a Struct that holds metadata a Blocksmith creator has uploaded.
    //
    // Creation NFTs will all reference a single blueprint as the owner of
    // its metadata. The blueprints are publicly accessible, so anyone can
    // read the metadata associated with a specific blueprint ID
    //
    pub struct Blueprint {

        // ID of the creator who created this blueprint
        pub let creatorID: UInt32

        // The unique ID for Blueprints created by this creator
        pub let blueprintID: UInt32

        // Count of how many Creations have been made from this Blueprint
        pub var creationCount: UInt32

        // Count of how many Creations can ever be made of this Blueprint
        pub let creationLimit: UInt32

        // Stores all the metadata about the blueprint as a string mapping
        pub let metadata: {String: String}

        init(creatorID: UInt32, metadata: {String: String}, creationLimit: UInt32?) {
            pre {
                Blocksmith.creators[creatorID] != nil: "Creator doesn't exist"
                metadata.length != 0: "New Blueprint metadata cannot be empty"
            }
            self.creatorID = creatorID
            self.blueprintID = Blocksmith.creators[creatorID]!.nextBlueprintID
            self.metadata = metadata

            self.creationCount = UInt32(0)
            self.creationLimit = creationLimit ?? UInt32.max

            // Increment the ID so that it isn't used again
            Blocksmith.creators[creatorID]!.incrementNextBlueprintID()

            emit BlueprintCreated(creatorID: creatorID, blueprintID: self.blueprintID, metadata: metadata)
        }

        pub fun canMint(): Bool {
            return self.creationCount < self.creationLimit
        }

        // Also returns if this is the last creation for this Blueprint
        pub fun incrementCreationCount() {
            pre {
                self.canMint(): "This Blueprint has reached its creation limit"
            }

            self.creationCount = self.creationCount + UInt32(1)
        }
    }

    // A Set is a grouping of Blueprints that have occured in the real world
    // that make up a related group of collectibles, like sets of baseball
    // or Magic cards. A Blueprint can exist in multiple different sets.
    // 
    // SetData is a struct that is stored in a field of the contract.
    // Anyone can query the constant information
    // about a set by calling various getters located 
    // at the end of the contract. Only the admin has the ability 
    // to modify any data in the private Set resource.
    //
    pub struct SetData {

        // ID of the creator who created this set
        pub let creatorID: UInt32

        // Unique ID for Sets created by this Creator
        pub let setID: UInt32

        // Name of the Set
        pub let name: String

        // Series that this Set belongs to.
        pub let series: UInt32

        // Indicates if the Set is currently locked.
        // A Set starts unlocked and Blueprints are allowed to be added to it.
        // When a Set is locked, Blueprints can no longer be added.
        // A Set can never be changed from locked to unlocked,
        // the decision to lock a Set it is final.
        // Though Blueprints cannot be added to locked Sets,
        // Creations can still be minted from Blueprints that exist in the Set.
        pub var locked: Bool

        // Array of blueprintIDs that are a part of this set.
        // When a blueprint is added to the set, its ID gets appended here.
        // The ID does not get removed from this array when a Blueprint is retired.
        pub var blueprintIDs: [UInt32]

        // Map of Blueprint IDs that Indicates if a Blueprint in this Set can be minted.
        // When a Blueprint is added to a Set, it is mapped to false (not retired).
        // When a Blueprint is retired, this is set to true and cannot be changed.
        pub var retired: {UInt32: Bool}

        // Mapping of Blueprint IDs that indicates the number of Creations 
        // that have been minted for this Set.
        // When a Creation is minted, this value is stored in the Creation to
        // show its place in the Set, eg. 13 of 60.
        pub var numberMintedPerBlueprint: {UInt32: UInt32}

        init(creatorID: UInt32, setID: UInt32) {
            pre {
                Blocksmith.sets[creatorID] != nil: "Creator must exist to get setData"
            }

            let creatorSets <- Blocksmith.sets.remove(key: creatorID)!

            let setToRead <- creatorSets.remove(key: setID) ?? panic("Set must exist to get setData")

            self.creatorID = setToRead.creatorID
            self.setID = setToRead.setID
            self.name = setToRead.name
            self.series = setToRead.series
            self.blueprintIDs = setToRead.blueprintIDs
            self.retired = setToRead.retired
            self.locked = setToRead.locked
            self.numberMintedPerBlueprint = setToRead.numberMintedPerBlueprint

            creatorSets[setID] <-! setToRead

            Blocksmith.sets[creatorID] <-! creatorSets
        }
    }

    // Set is a resource type that contains the functions to add and remove
    // Blueprints from a set and mint Creations.
    //
    // It is stored in a private field in the contract so that
    // the admin resource can call its methods.
    //
    // The admin can add Blueprints to a Set so that the set can mint Creations
    // that reference that blueprintdata.
    // The Creations that are minted by a Set will be listed as belonging to
    // the Set that minted it, as well as the Blueprint it references.
    // 
    // Admin can also retire Blueprints from the Set, meaning that the retired
    // Blueprint can no longer have Creations minted from it.
    //
    // If the admin locks the Set, no more Blueprints can be added to it, but 
    // Creations can still be minted.
    //
    // If retireAll() and lock() are called back-to-back, 
    // the Set is closed off forever and nothing more can be done with it.
    pub resource Set {

        // ID of the creator who created this set
        pub let creatorID: UInt32

        // Unique ID for Sets created by this Creator
        pub let setID: UInt32

        // Name of the Set
        pub let name: String

        // Series that this Set belongs to.
        pub let series: UInt32
        
        // Indicates if the Set is currently locked.
        // A Set starts unlocked and Blueprints are allowed to be added to it.
        // When a Set is locked, Blueprints can no longer be added.
        // A Set can never be changed from locked to unlocked,
        // the decision to lock a Set it is final.
        // Though Blueprints cannot be added to locked Sets,
        // Creations can still be minted from Blueprints that exist in the Set.
        pub var locked: Bool

        // Array of blueprintIDs that are a part of this set.
        // When a blueprint is added to the set, its ID gets appended here.
        // The ID does not get removed from this array when a Blueprint is retired.
        pub var blueprintIDs: [UInt32]

        // Map of Blueprint IDs that Indicates if a Blueprint in this Set can be minted.
        // When a Blueprint is added to a Set, it is mapped to false (not retired).
        // When a Blueprint is retired, this is set to true and cannot be changed.
        pub var retired: {UInt32: Bool}
        
        // Mapping of Blueprint IDs that indicates the number of Creations 
        // that have been minted for this Set.
        // When a Creation is minted, this value is stored in the Creation to
        // show its place in the Set, eg. 13 of 60.
        pub var numberMintedPerBlueprint: {UInt32: UInt32}

        init(creatorID: UInt32, name: String) {
            pre {
                Blocksmith.creators[creatorID] != nil: "Creator must exist to create Set"
                name.length > 0: "New Set name cannot be empty"
            }

            self.creatorID = creatorID
            self.setID =  Blocksmith.creators[creatorID]!.nextSetID
            self.name = name
            self.series =  Blocksmith.creators[creatorID]!.currentSeries

            self.blueprintIDs = []
            self.retired = {}
            self.locked = false
            self.numberMintedPerBlueprint = {}

            // Increment the setID so that it isn't used again
            Blocksmith.creators[creatorID]!.incrementNextSetID()

            emit SetCreated(creatorID: creatorID, setID: self.setID, series: self.series)
        }

        // addBlueprint adds a blueprint to the set
        //
        // Parameters: blueprintID: The ID of the Blueprint that is being added
        //
        // Pre-Conditions:
        // The Blueprint needs to be an existing blueprint
        // The Set needs to be not locked
        // The Blueprint can't have already been added to the Set
        //
        pub fun addBlueprint(blueprintID: UInt32) {
            pre {
                Blocksmith.creators[self.creatorID]!.containsBlueprint(blueprintID: blueprintID): 
                    "Cannot add the Blueprint to Set: Blueprint doesn't exist."
                !self.locked: 
                    "Cannot add the blueprint to the Set after the set has been locked."
                !self.blueprintIDs.contains(blueprintID): 
                    "The blueprint has already beed added to the set."
            }
            post {
                self.blueprintIDs.contains(blueprintID): 
                    "blueprint not created properly"
                self.retired[blueprintID] == false:
                    "The Set's retired map is not set to false"
                self.numberMintedPerBlueprint[blueprintID] == 0:
                    "The Set's number minted should start at 0"
            }

            // Add the Blueprint to the array of Blueprints
            self.blueprintIDs.append(blueprintID)

            // Open the Blueprint up for minting
            self.retired[blueprintID] = false

            // Initialize the Creation count to zero
            self.numberMintedPerBlueprint[blueprintID] = 0

            emit BlueprintAddedToSet(creatorID: self.creatorID, setID: self.setID, blueprintID: blueprintID)
        }

        // addBlueprints adds multiple Blueprints to the Set
        //
        // Parameters: blueprintIDs: The IDs of the Blueprints that are being added
        //                      as an array
        //
        pub fun addBlueprints(blueprintIDs: [UInt32]) {
            for blueprintID in blueprintIDs {
                self.addBlueprint(blueprintID: blueprintID)
            }
        }

        // retireBlueprint retires a Blueprint from the Set so that it can't mint new Creations
        //
        // Parameters: blueprintID: The ID of the Blueprint that is being retired
        //
        // Pre-Conditions:
        // The Blueprint is part of the Set and not retired (available for minting).
        // 
        pub fun retireBlueprint(blueprintID: UInt32) {
            pre {
                self.retired[blueprintID] != nil: "Cannot retire the Blueprint: Blueprint doesn't exist in this set!"
            }
            post {
                self.retired[blueprintID]!: "Blueprint should be retired in this set"
            }

            if !self.retired[blueprintID]! {
                self.retired[blueprintID] = true

                emit BlueprintRetiredFromSet(
                    creatorID: self.creatorID, 
                    setID: self.setID, 
                    blueprintID: blueprintID, 
                    numCreations: self.numberMintedPerBlueprint[blueprintID]!
                )
            }
        }

        // retireAll retires all the blueprints in the Set
        // Afterwards, none of the retired Blueprints will be able to mint new Creations
        //
        pub fun retireAll() {
            for blueprintID in self.blueprintIDs {
                self.retireBlueprint(blueprintID: blueprintID)
            }
        }

        // lock() locks the Set so that no more Blueprints can be added to it
        //
        // Pre-Conditions:
        // The Set should not be locked
        pub fun lock() {
            post {
                Blocksmith.isSetLocked(creatorID: self.creatorID, setID: self.setID)!:
                    "set wasn't locked properly"
            }

            if !self.locked {
                self.locked = true
                emit SetLocked(setID: self.setID)
            }
        }

        // mintCreation mints a new Creation and returns the newly minted Creation
        // 
        // Parameters: blueprintID: The ID of the Blueprint that the Creation references
        //
        // Pre-Conditions:
        // The Blueprint must exist in the Set and be allowed to mint new Creations
        // The Blueprint must have not reached its creation limit
        //
        // Returns: The NFT that was minted
        // 
        pub fun mintCreation(blueprintID: UInt32): @NFT {
            pre {
                self.retired[blueprintID] != nil: 
                    "Cannot mint a creation: This blueprint doesn't exist in this set."
                !self.retired[blueprintID]!: 
                    "Cannot mint a creation from this blueprint: This set has retired this blueprint."
                Blocksmith.creators[self.creatorID]!.canMint(blueprintID: blueprintID):
                    "Cannot mint a creation from this blueprint. It is at it's creation limit."
            }

            // Gets the number of Creations that have been minted for this Blueprint
            // to use as this Creation's serial number
            let numInBlueprint = self.numberMintedPerBlueprint[blueprintID]!

            // Mint the new creation
            let newCreation: @NFT <- create NFT(creatorID: self.creatorID,
                                              setID: self.setID,
                                              blueprintID: blueprintID,
                                              serialNumber: numInBlueprint + UInt32(1))

             Blocksmith.creators[self.creatorID]!.incrementCreationCount(blueprintID: blueprintID)

            // Increment the count of Creations minted for this Blueprint
            self.numberMintedPerBlueprint[blueprintID] = numInBlueprint + UInt32(1)

            return <-newCreation
        }

        // batchMintCreation mints an arbitrary quantity of Creations 
        // and returns them as a Collection
        //
        // Parameters: blueprintID: the ID of the Blueprint that the Creations are minted for
        //             quantity: The quantity of Creations to be minted
        //
        // Returns: Collection object that contains all the Creations that were minted
        //
        pub fun batchMintCreation(blueprintID: UInt32, quantity: UInt64): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintCreation(blueprintID: blueprintID))
                i = i + UInt64(1)
            }

            return <-newCollection
        }
    }

    pub struct CreationData {

        // The ID of the Creator who created this
        pub let creatorID: UInt32

        // Unique ID for a specific creator's creations
        pub let creationID: UInt32

        // The ID of the Set that the Creation comes from
        pub let setID: UInt32

        // The ID of the Blueprint that the Creation references
        pub let blueprintID: UInt32

        // The place in the edition that this Creation was minted
        // Otherwise know as the serial number
        pub let serialNumber: UInt32

        init(creatorID: UInt32, creationID: UInt32, setID: UInt32, blueprintID: UInt32, serialNumber: UInt32) {
            self.creatorID = creatorID
            self.creationID = creationID
            self.setID = setID
            self.blueprintID = blueprintID
            self.serialNumber = serialNumber
        }
    }

    // The resource that represents the Creation NFTs
    //
    pub resource NFT: NonFungibleToken.INFT {

        // Global unique creation ID across all creators
        pub let id: UInt64
        
        // Struct of Creation metadata
        pub let data: CreationData

        init(creatorID: UInt32, setID: UInt32, blueprintID: UInt32, serialNumber: UInt32) {
            // Increment the global Creation IDs
            Blocksmith.totalSupply = Blocksmith.totalSupply + UInt64(1)
            self.id = Blocksmith.totalSupply

            Blocksmith.creators[creatorID]!.incrementNumCreations()
            let creationID = Blocksmith.creators[creatorID]!.numCreations

            // Set the metadata struct
            self.data = CreationData(
                creatorID: creatorID,
                creationID: creationID,
                setID: setID, 
                blueprintID: blueprintID, 
                serialNumber: serialNumber
            )

            emit CreationMinted(
                globalCreationID: self.id, 
                creatorID: self.data.creatorID,
                creationID: self.data.creationID, 
                blueprintID: self.data.blueprintID, 
                setID: self.data.setID, 
                serialNumber: self.data.serialNumber
            )
        }

        // If the Creation is destroyed, emit an event to indicate 
        // to outside ovbservers that it has been destroyed
        destroy() {
            emit CreationDestroyed(id: self.id)
        }
    }

    // SuperAdmin is a special authorization resource that 
    // allows the owner to onboard new Creators onto the contract
    // and grant admin access to any creator through an AdminPubilc reference
    pub resource SuperAdmin {

        pub fun createCreator(creatorAddress: Address): UInt32 {
            post {
                Blocksmith.getCreator(creatorID: newCreatorID) != nil:
                    "Could not create the new creator"
                Blocksmith.getCreator(creatorID: newCreatorID)!.creatorAddress == creatorAddress:
                    "Could not set the proper creatorAddress"
                Blocksmith.nextCreatorID == newCreatorID + UInt32(1):
                    "Could not set the next creatorID"
            }

            var newCreator = Creator(creatorAddress: creatorAddress)
            let newCreatorID = newCreator.creatorID
            Blocksmith.creators[newCreatorID] = newCreator

            return newCreator.creatorID
        }

        pub fun addCreatorIDsToAdmin(creatorIDs: [UInt32], adminRef: &{AdminPublic}) {
            adminRef.addCreatorAccess(creatorIDs: creatorIDs)
        }

        pub fun createNewSuperAdmin(): @SuperAdmin {
            return <-create SuperAdmin()
        }
    }

    // This is the interface that allows Admins to give 
    // another wallet admin priviledges on a creator.
    // Once given these priviledges cannot be revoked, even by a superAdmin
    pub resource interface AdminPublic {

        // Admins can only perform actions on Creators with ids in this list
        pub fun getCreatorAccess(): {UInt32: Bool}

        // SuperAdmin resource is required to ensure extender has the proper 
        access(contract) fun addCreatorAccess(creatorIDs: [UInt32])
        // Admin resource is required to ensure extender has the proper 
        // admin permission to extend creator Access
        pub fun extendCreatorAccess(creatorID: UInt32, extender: &Admin)
        pub fun extendCreatorsAccess(creatorIDs: [UInt32], extender: &Admin)
    }

    // Admin is a special authorization resource that 
    // allows the creator to perform important functions to modify the 
    // various aspects of the Blueprints, Sets, and Creations for some creators
    //
    pub resource Admin: AdminPublic {

        // Admins can only perform actions on Creators with ids in this list
        // SuperAdmins can change which creatorIDs an Admin can modify
        access(self) var creatorAccess: {UInt32: Bool}

        init(creatorAccess: {UInt32: Bool}?) {
            self.creatorAccess = creatorAccess ?? {}
        }

        pub fun getCreatorAccess(): {UInt32: Bool} {
            return self.creatorAccess
        }

        pub fun updateCreatorMetadata(creatorID: UInt32, metadata: {String: String}) {
            pre {
                Blocksmith.creators[creatorID] != nil: 
                    "Cannot create Blueprint: Creator does not exist"
                // false if the value is false or if the key does not exist
                self.creatorAccess[creatorID] ?? false: 
                    "Unable to modify anything for this Creator"
            }

            Blocksmith.creators[creatorID]!.updateMetadata(updatedData: metadata)
        }

        // createBlueprint creates a new Blueprint struct 
        // and stores it in the Blueprints dictionary in the Blocksmith smart contract
        //
        // Parameters: metadata: A dictionary mapping metadata titles to their data
        //                       example: {"Name": "John Doe", "Height": "6 feet"}
        //
        // Returns: the ID of the new Blueprint object
        //
        pub fun createBlueprint(creatorID: UInt32, metadata: {String: String}, creationLimit: UInt32?): UInt32 {
            pre {
                Blocksmith.creators[creatorID] != nil: 
                    "Cannot create Blueprint: Creator does not exist"
                // false if the value is false or if the key does not exist
                self.creatorAccess[creatorID] ?? false: 
                    "Unable to modify anything for this Creator"
            }
            post {
                Blocksmith.creators[creatorID]!.nextBlueprintID == newID + UInt32(1):
                    "Creator not set up for next blueprint"
                Blocksmith.getBlueprintMetaData(creatorID: creatorID, blueprintID: newID) != nil:
                    "Blueprint wasn't saved properly"
            }

            // Create the new Blueprint
            var newBlueprint = Blueprint(creatorID: creatorID, metadata: metadata, creationLimit: creationLimit)
            let newID = newBlueprint.blueprintID

            // Store it in the contract storage
            Blocksmith.creators[creatorID]!.addBlueprint(blueprintID: newID, blueprint: newBlueprint)

            return newID
        }

        // createSet creates a new Set resource and stores it
        // in the sets mapping in the Blocksmith contract
        //
        // Parameters: name: The name of the Set
        //
        pub fun createSet(creatorID: UInt32, name: String) {
            pre {
                Blocksmith.creators[creatorID] != nil: "Cannot create Set: Creator does not exist"
                // false if the value is false or if the key does not exist
                self.creatorAccess[creatorID] ?? false: 
                    "Unable to modify anything for this Creator"
            }
            post {
                Blocksmith.getSetName(creatorID: creatorID, setID: newSetID) == name:
                    "New set does not have the right name"
                Blocksmith.creators[creatorID]!.nextSetID == newSetID + UInt32(1):
                    "Did not increment nextSetID properly"
            }

            // Create the new Set
            var newSet <- create Set(creatorID: creatorID, name: name)
            let newSetID = newSet.setID
            // Store it in the sets mapping field
            let creatorSets <- Blocksmith.sets.remove(key: creatorID)!
            creatorSets[newSetID] <-! newSet
            
            Blocksmith.sets[creatorID] <-! creatorSets
        }

        // borrowSet returns a reference to a set in the Blocksmith
        // contract so that the admin can call methods on it
        //
        // Parameters: setID: The ID of the Set that you want to
        // get a reference to
        //
        // Returns: A reference to the Set with all of the fields
        // and methods exposed
        //
        pub fun borrowSet(creatorID: UInt32, setID: UInt32): &Set {
            pre {
                Blocksmith.creators[creatorID] != nil: "Cannot borrow Set: The Creator doesn't exist"                
                // false if the value is false or if the key does not exist
                self.creatorAccess[creatorID] ?? false: 
                    "Unable to modify anything for this Creator"
            }
            
            let creatorSets <- Blocksmith.sets.remove(key: creatorID)!

            if creatorSets[setID] == nil {
                panic("Cannot borrow Set: The Set doesn't exist")
            }

            // Get a reference to the Set and return it
            // use `&` to indicate the reference to the object and type
            let reference: &Set = &creatorSets[setID] as &Set
            
            Blocksmith.sets[creatorID] <-! creatorSets

            return reference
        }

        // startNewSeries ends the current series by incrementing
        // the series number, meaning that Creations minted after this
        // will use the new series number
        //
        // Returns: The new series number
        //
        pub fun startNewSeries(creatorID: UInt32): UInt32 {
            pre {
                Blocksmith.creators[creatorID] != nil: "Cannot start series: The Creator doesn't exist"
                // false if the value is false or if the key does not exist
                self.creatorAccess[creatorID] ?? false: 
                    "Unable to modify anything for this Creator"
            }

            // End the current series and start a new one
            // by incrementing the Blocksmith series number
            Blocksmith.creators[creatorID]!.incrementCurrentSeries()

            let currentSeries = Blocksmith.creators[creatorID]!.currentSeries

            emit NewSeriesStarted(creatorID: creatorID, newCurrentSeries: currentSeries)

            return currentSeries
        }

        // Admin can remove their own access over a creator if they want
        pub fun removeCreatorAccess(creatorIDs: [UInt32]) {
            for creatorID in creatorIDs {
                self.creatorAccess[creatorID] = false
            }
        }

        // This is contract access so that only the SuperAdmin resource
        // can grant admin access for other creators
        access(contract) fun addCreatorAccess(creatorIDs: [UInt32]) {
            for creatorID in creatorIDs {
                if (Blocksmith.creators[creatorID] == nil) {
                    panic("Cannot give access to a creator that doesn't exist")
                }
                self.creatorAccess[creatorID] = true
            }
        }
        
        // These methods are mostly for Admins with more 
        pub fun extendCreatorAccess(creatorID: UInt32, extender: &Admin) {
            pre {
                extender.creatorAccess[creatorID] ?? false:
                    "Provided Admin resource does not have access for this creator"
            }
            self.creatorAccess[creatorID] = extender.creatorAccess[creatorID]!
        }

        pub fun extendCreatorsAccess(creatorIDs: [UInt32], extender: &Admin) {
            for creatorID in creatorIDs {
                if extender.creatorAccess[creatorID] ?? false {
                    panic("Provided Admin resource does not have access for these creators")
                }

                self.creatorAccess[creatorID] = extender.creatorAccess[creatorID]!
            }
        }
    }

    // This is the interface that users can cast their Creation Collection as
    // to allow others to deposit Creations into their Collection. It also allows for reading
    // the IDs of Creations in the Collection.
    pub resource interface CreationCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT

        // This id is the global UInt64 ID which is unique across ALL Creators
        pub fun borrowCreation(id: UInt64): &Blocksmith.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Creation reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection is a resource that every user who owns NFTs 
    // will store in their account to manage their NFTS
    //
    pub resource Collection: CreationCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic { 
        // Dictionary of Creation conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an Creation from the Collection and moves it to the caller
        //
        // Parameters: withdrawID: The ID of the NFT 
        // that is to be removed from the Collection
        //
        // returns: @NonFungibleToken.NFT the token that was withdrawn
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: Creation does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)
            
            // Return the withdrawn token
            return <-token
        }

        // batchWithdraw withdraws multiple tokens and returns them as a Collection
        //
        // Parameters: ids: An array of IDs to withdraw
        //
        // Returns: @NonFungibleToken.Collection: A collection that contains
        //                                        the withdrawn creations
        //
        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            // Return the withdrawn tokens
            return <-batchCollection
        }

        // deposit takes a Creation and adds it to the Collections dictionary
        //
        // Paramters: token: the NFT to be deposited in the collection
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            
            // Cast the deposited token as a Blocksmith NFT to make sure
            // it is the correct type
            let token <- token as! @Blocksmith.NFT

            // Get the token's ID
            let id = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Only emit a deposit event if the Collection 
            // is in an account's storage
            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            // Destroy the empty old token that was "removed"
            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the Collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT Returns a borrowed reference to a Creation in the Collection
        // so that the caller can read its ID
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        //
        // Note: This only allows the caller to read the ID of the NFT,
        // not any Blocksmith specific data. Please use borrowCreation to 
        // read Creation data.
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        // borrowCreation returns a borrowed reference to a Creation
        // so that the caller can read data and call methods from it.
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        pub fun borrowCreation(id: UInt64): &Blocksmith.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &Blocksmith.NFT
            } else {
                return nil
            }
        }

        // If a transaction destroys the Collection object,
        // All the NFTs contained within are also destroyed!
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // Blocksmith contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection creates a new, empty Collection object so that
    // a user can store it in their account storage.
    // Once they have a Collection in their storage, they are able to receive
    // Creations in transactions.
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create Blocksmith.Collection()
    }

    // createEmptyAdmin creates a new, Admin object that a user can store 
    // in their account storage. It initally has access to no creator accounts,
    // and the user must make a public capability to allow existing Admins
    // or SuperAdmins to extend their admin capability.
    pub fun createEmptyAdmin(): @Blocksmith.Admin {
        return <-create Blocksmith.Admin(nil)
    }

    // getCreator returns all data related to a Creator struct
    //
    // Returns: An optional of a Creator struct if the creatorID exists
    pub fun getCreator(creatorID: UInt32): Blocksmith.Creator? {
        return Blocksmith.creators[creatorID]
    }

    // getAllBlueprints returns all the blueprints in this Blocksmith
    //
    // Returns: An array of all the blueprints that have been created
    pub fun getBlueprints(creatorID: UInt32): [Blocksmith.Blueprint] {
        pre {
            Blocksmith.creators[creatorID] != nil: "Creator must exist to get blueprints"
        }

        return Blocksmith.creators[creatorID]!.getBlueprints()
    }

    // getBlueprint returns an optional which is either the blueprint
    // with that id for the creator or empty if it doesn't exist
    //
    // Returns: An option the blueprint with that ID
    pub fun getBlueprint(creatorID: UInt32, blueprintID: UInt32): Blocksmith.Blueprint? {
        pre {
            Blocksmith.creators[creatorID] != nil: "Creator must exist to get blueprints"
        }

        return Blocksmith.creators[creatorID]!.getBlueprint(blueprintID: blueprintID)
    }

    // getBlueprintMetaData returns all the metadata associated with a specific Blueprint
    // 
    // Parameters: blueprintID: The id of the Blueprint that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getBlueprintMetaData(creatorID: UInt32, blueprintID: UInt32): {String: String}? {
        pre {
            Blocksmith.creators[creatorID] != nil: "Creator must exist to get blueprints"
        }

        return Blocksmith.creators[creatorID]!.getBlueprintMetaData(blueprintID: blueprintID)
    }

    // getBlueprintMetaDataByField returns the metadata associated with a 
    //                        specific field of the metadata
    //                        Ex: field: "Author" will return something
    //                        like "John Doe"
    // 
    // Parameters: blueprintID: The id of the Blueprint that is being searched
    //             field: The field to search for
    //
    // Returns: The metadata field as a String Optional
    pub fun getBlueprintMetaDataByField(creatorID: UInt32, blueprintID: UInt32, field: String): String? {
        pre {
            Blocksmith.creators[creatorID] != nil: "Creator must exist to get blueprints"
        }

        return Blocksmith.creators[creatorID]!.getBlueprintMetaDataByField(blueprintID: blueprintID, field: field)
    }


    // getSetName returns the name that the specified Set
    //            is associated with.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: The name of the Set
    pub fun getSetName(creatorID: UInt32, setID: UInt32): String? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        var name: String? = nil
        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!
        
        // Don't force a revert if the setID is invalid
        name = creatorSets[setID]?.name

        Blocksmith.sets[creatorID] <-! creatorSets

        return name
    }

    // getSetSeries returns the series that the specified Set
    //              is associated with.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: The series that the Set belongs to
    pub fun getSetSeries(creatorID: UInt32, setID: UInt32): UInt32? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!
        
        // Don't force a revert if the setID is invalid
        let series = creatorSets[setID]?.series
        Blocksmith.sets[creatorID] <-! creatorSets

        return series
    }

    // getBlueprintsInSet returns the list of Blueprint IDs that are in the Set
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: An array of Blueprint IDs
    pub fun getBlueprintsInSet(creatorID: UInt32, setID: UInt32): [UInt32]? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!
        
        // Don't force a revert if the setID is invalid
        let blueprintIDs = creatorSets[setID]?.blueprintIDs
        Blocksmith.sets[creatorID] <-! creatorSets

        return blueprintIDs
    }

    // isEditionRetired returns a boolean that indicates if a Set/Blueprint combo
    //                  (otherwise known as an edition) is retired.
    //                  If an edition is retired, it still remains in the Set,
    //                  but Creations can no longer be minted from it.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //             blueprintID: The id of the Blueprint that is being searched
    //
    // Returns: Boolean indicating if the edition is retired or not
    pub fun isEditionRetired(creatorID: UInt32, setID: UInt32, blueprintID: UInt32): Bool? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        var isRetired: Bool? = nil
        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!

        // Don't force a revert if the Set or blueprint ID is invalid
        // Remove the Set from the dictionary to get its field        
        if let setToRead <- creatorSets.remove(key: setID) {

            // See if the Blueprint is retired from this Set
            isRetired = setToRead.retired[blueprintID]

            // Put the Set back into the creatorSets dictionary
            creatorSets[setID] <-! setToRead
        } 

        // Put the Set back into the Sets dictionary
        Blocksmith.sets[creatorID] <-! creatorSets

        return isRetired
    }

    // isSetLocked returns a boolean that indicates if a Set
    //             is locked. If it's locked, 
    //             new Blueprints can no longer be added to it,
    //             but Creations can still be minted from Blueprints the set contains.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: Boolean indicating if the Set is locked or not
    pub fun isSetLocked(creatorID: UInt32, setID: UInt32): Bool? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!
        
        // Don't force a revert if the setID is invalid
        let locked = creatorSets[setID]?.locked
        Blocksmith.sets[creatorID] <-! creatorSets

        return locked
    }

    // getNumCreationsInEdition return the number of Creations that have been 
    //                        minted from a certain edition.
    //
    // Parameters: setID: The id of the Set that is being searched
    //             blueprintID: The id of the Blueprint that is being searched
    //
    // Returns: The total number of Creations 
    //          that have been minted from an edition
    pub fun getNumCreationsInEdition(creatorID: UInt32, setID: UInt32, blueprintID: UInt32): UInt32? {
        pre {
            Blocksmith.sets[creatorID] != nil: "Creator must exist to get blueprints"
        }

        var numCreations: UInt32? = nil
        let creatorSets <- Blocksmith.sets.remove(key: creatorID)!

        // Don't force a revert if the Set or blueprint ID is invalid
        // Remove the Set from the dictionary to get its field        
        if let setToRead <- creatorSets.remove(key: setID) {

            // Read the numMintedPerBlueprint
            numCreations = setToRead.numberMintedPerBlueprint[blueprintID]

            // Put the Set back into the creatorSets dictionary
            creatorSets[setID] <-! setToRead
        } 

        // Put the Set back into the Sets dictionary
        Blocksmith.sets[creatorID] <-! creatorSets

        return numCreations
    }

    // fetch
    // Get a reference to a Creation from an account's Collection, if available.
    // If an account does not have a Blocksmith.Collection, panic.
    // If it has a collection but does not contain the creationID, return nil.
    // If it has a collection and that collection contains the creationID, return a reference to that.
    //
    pub fun fetch(_ from: Address, globalCreationID: UInt64): &Blocksmith.NFT? {
        let collection = getAccount(from)
            .getCapability(Blocksmith.CollectionPublicPath)
            .borrow<&Blocksmith.Collection{Blocksmith.CreationCollectionPublic}>()
            ?? panic("Couldn't get collection")

        // We trust Blocksmith.Collection.borrowCreation to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowCreation(id: globalCreationID)
    }
}