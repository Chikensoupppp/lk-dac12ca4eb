import CloudKit
import UIKit
import UserNotifications

/// Asking a Key Holder from far away, through Apple's iCloud (CloudKit public database).
/// No Lock In server: Apple stores two small record types and sends the push.
///
/// - UnlockRequest: written by the person asking. The reason is encrypted to the Key Holder,
///   and the request is signed. Fields: requestID, holderID, requesterID, requesterName,
///   sessionID, nonce, payload, signature, createdAt.
/// - UnlockAnswer: written by the Key Holder, signed. Fields: requestID, nonce, approved, signature.
/// The Key Holder's phone subscribes to requests addressed to it, so iCloud pushes a notification.
/// Both people must be signed in to iCloud. Records must exist in the production schema (see HANDOFF).
enum RemoteKeys {
    static let containerID = "iCloud.com.brandon132199.lockin"
    private static var db: CKDatabase { CKContainer(identifier: containerID).publicCloudDatabase }

    struct Pending: Identifiable, Equatable {
        var id: String { ask.requestID }
        let ask: UnlockAsk
        let name: String
    }

    // MARK: Asking

    static func send(_ ask: UnlockAsk, myName: String, to holder: KeyPerson) async throws {
        let record = CKRecord(recordType: "UnlockRequest")
        record["requestID"] = ask.requestID
        record["holderID"] = holder.id
        record["requesterID"] = ask.from
        record["requesterName"] = myName
        record["sessionID"] = ask.sessionID
        record["nonce"] = ask.nonce
        record["payload"] = (KeyStore.seal(ask.reason, to: holder) ?? Data()).base64EncodedString()
        record["signature"] = ask.signature.base64EncodedString()
        record["createdAt"] = Date.now
        _ = try await db.save(record)
    }

    /// The Key Holder's answer to one request, if there is one yet.
    static func answer(for requestID: String) async throws -> UnlockAnswer? {
        let query = CKQuery(recordType: "UnlockAnswer", predicate: NSPredicate(format: "requestID == %@", requestID))
        let (results, _) = try await db.records(matching: query, resultsLimit: 1)
        guard let record = try results.first?.1.get(),
              let nonce = record["nonce"] as? String,
              let approved = record["approved"] as? Int64,
              let sig = (record["signature"] as? String).flatMap({ Data(base64Encoded: $0) }) else { return nil }
        return UnlockAnswer(requestID: requestID, nonce: nonce, approved: approved == 1, signature: sig)
    }

    // MARK: Holding someone's key

    /// Requests from the last 30 minutes addressed to me, from people I hold keys for, checked
    /// against their signatures. The reason is decrypted on this phone only.
    @MainActor
    static func pending(for keys: KeyStore) async throws -> [Pending] {
        guard !keys.friends.isEmpty else { return [] }
        let since = Date.now.addingTimeInterval(-QuitRules.remoteTimeout)
        let predicate = NSPredicate(format: "holderID == %@ AND createdAt > %@", keys.myID, since as NSDate)
        let (results, _) = try await db.records(matching: CKQuery(recordType: "UnlockRequest", predicate: predicate), resultsLimit: 20)
        var out: [Pending] = []
        for (_, result) in results {
            guard let r = try? result.get(),
                  let requestID = r["requestID"] as? String, let from = r["requesterID"] as? String,
                  let sessionID = r["sessionID"] as? String, let nonce = r["nonce"] as? String,
                  let sig = (r["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let friend = keys.friends.first(where: { $0.id == from }) else { continue }
            let text = KeyStore.requestText(requestID: requestID, from: from, to: keys.myID, sessionID: sessionID, nonce: nonce)
            guard KeyStore.verify(sig, of: text, by: friend) else { continue }
            if try await answer(for: requestID) != nil { continue }
            let reason = (r["payload"] as? String).flatMap { Data(base64Encoded: $0) }.flatMap { keys.open($0) } ?? ""
            out.append(Pending(ask: UnlockAsk(requestID: requestID, from: from, to: keys.myID, sessionID: sessionID,
                                              nonce: nonce, reason: reason, signature: sig), name: friend.name))
        }
        return out
    }

    @MainActor
    static func reply(to ask: UnlockAsk, approved: Bool, keys: KeyStore) async throws {
        let record = CKRecord(recordType: "UnlockAnswer")
        record["requestID"] = ask.requestID
        record["nonce"] = ask.nonce
        record["approved"] = Int64(approved ? 1 : 0)
        record["signature"] = keys.sign(KeyStore.answerText(requestID: ask.requestID, nonce: ask.nonce, approved: approved)).base64EncodedString()
        record["createdAt"] = Date.now
        _ = try await db.save(record)
    }

    /// Lets iCloud push "someone wants out" to this phone. Safe to call often.
    @MainActor
    static func subscribe(for keys: KeyStore) async {
        guard !keys.friends.isEmpty else { return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
        let id = "lockin.asks.\(keys.myID)"
        if (try? await db.subscription(for: id)) != nil { return }
        let sub = CKQuerySubscription(recordType: "UnlockRequest", predicate: NSPredicate(format: "holderID == %@", keys.myID),
                                      subscriptionID: id, options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.title = "A friend wants out"
        info.alertBody = "Someone you hold a key for wants to end their Lock In session. Open Lock In to answer."
        info.soundName = "default"
        sub.notificationInfo = info
        _ = try? await db.save(sub)
    }
}
