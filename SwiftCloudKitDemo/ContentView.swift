//
//  ContentView.swift
//  SwiftCloudKitDemo
//
//  Created by Daniel  Gushchyan on 1/8/25.
//

import SwiftUI
import CoreData
import CryptoKit

struct ContentView: View {
    @State private var privateKeyString: String = "Loading..."
    @State private var lastUpdated: Date = Date()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Private Key Info")
                .font(.title)
            
            Text(privateKeyString)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Last Updated: \(lastUpdated.formatted())")
                .font(.caption)
            
            Button("Refresh") {
                Task {
                    await loadPrivateKey()
                }
            }
            Button(role: .destructive) {
                Task {
                    do {
                        try await PrivateKeyManager.shared.deleteAllKeys()
                    } catch {
                        print("Error deleting keys: \(error)")
                    }
                }
            } label: {
                Text("Delete All Keys")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .task {
            await loadPrivateKey()
        }
        // Add periodic refresh
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await loadPrivateKey()
            }
        }
    }
    
    private func loadPrivateKey() async {
        do {
            let privateKey = try await PrivateKeyManager.shared.getOrCreatePrivateKey()
            let publicKey = privateKey.publicKey
            let keyData = publicKey.rawRepresentation
            
            privateKeyString = "Public Key (hex):\n" + keyData.map { String(format: "%02x", $0) }.joined()
            lastUpdated = Date()
        } catch {
            privateKeyString = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
