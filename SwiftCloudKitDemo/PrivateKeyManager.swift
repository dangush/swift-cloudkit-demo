import Foundation
import CoreData
import CryptoKit
import CloudKit

class PrivateKeyManager {
    static let shared = PrivateKeyManager()
    private let persistenceController: PersistenceController
    
    private init() {
        persistenceController = PersistenceController.shared
    }
    
    func getOrCreatePrivateKey() async throws -> P256.KeyAgreement.PrivateKey {
        let context = persistenceController.container.viewContext
        
        // Try to fetch existing keys
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PrivateKey")
        // Sort by creation date to always get the oldest key first
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        let results = try context.fetch(fetchRequest)
        
        if results.count > 1 {
            print("Found multiple keys, cleaning up duplicates...")
            // Keep the oldest key and delete the rest
            let oldestKey = results[0]
            for extraKey in results[1...] {
                context.delete(extraKey)
            }
            try context.save()
            
            if let keyData = oldestKey.value(forKey: "keyData") as? Data {
                print("Using oldest existing key")
                return try P256.KeyAgreement.PrivateKey(rawRepresentation: keyData)
            }
        } else if let existingKeyData = results.first?.value(forKey: "keyData") as? Data {
            print("Found single existing key")
            return try P256.KeyAgreement.PrivateKey(rawRepresentation: existingKeyData)
        }
        
        print("No valid key found, creating new one")
        
        // Before creating a new key, try to sync with CloudKit
        try await syncWithCloudKit()
        
        // Check again after sync
        let resultsAfterSync = try context.fetch(fetchRequest)
        if let existingKeyData = resultsAfterSync.first?.value(forKey: "keyData") as? Data {
            print("Found existing key after CloudKit sync")
            return try P256.KeyAgreement.PrivateKey(rawRepresentation: existingKeyData)
        }
        
        // Still no key found, create new one
        let newKey = P256.KeyAgreement.PrivateKey()
        let keyData = newKey.rawRepresentation
        
        let privateKeyEntity = NSEntityDescription.insertNewObject(forEntityName: "PrivateKey", into: context)
        privateKeyEntity.setValue(keyData, forKey: "keyData")
        privateKeyEntity.setValue(Date(), forKey: "createdAt")
        
        try context.save()
        
        print("Created and saved new key")
        return newKey
    }
    
    private func syncWithCloudKit() async throws {
        print("Starting CloudKit sync...")
        
        // Check iCloud status with retries
        var accountStatus: CKAccountStatus = .couldNotDetermine
        for attempt in 1...3 {
            print("Checking iCloud status (attempt \(attempt))...")
            accountStatus = try await CKContainer.default().accountStatus()
            print("iCloud account status: \(accountStatus.rawValue)")
            
            if accountStatus == .available {
                break
            }
            
            if attempt < 3 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second between attempts
            }
        }
        
        // Only warn if we're really sure there's no account
        if accountStatus == .noAccount {
            print("No iCloud account available")
            return
        }
        
        // Proceed with sync even if status is .couldNotDetermine
        // Trigger a save on the context which will initiate a CloudKit sync
        if persistenceController.container.viewContext.hasChanges {
            try persistenceController.container.viewContext.save()
        }
        
        // Wait longer for sync to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        print("CloudKit sync completed")
    }
    
    func checkiCloudStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            print("iCloud Status: \(status.rawValue)")
        } catch {
            print("Error checking iCloud status: \(error)")
        }
    }
    
    func deleteAllKeys() async throws {
        let context = persistenceController.container.viewContext
        
        // Delete from CoreData
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PrivateKey")
        let keys = try context.fetch(fetchRequest)
        
        for key in keys {
            context.delete(key)
        }
        
        try context.save()
        
        // Wait for CloudKit sync to propagate the deletions
        try await syncWithCloudKit()
        
        print("All keys deleted")
    }
}
