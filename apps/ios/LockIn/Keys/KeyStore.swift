import CryptoKit
import Foundation
import Security

/// Friend Key: a trusted friend (the Key Holder) is the only way out of a Locked session.
///
/// Each phone has its own identity: a random id, a signing key and a key-agreement key, kept in
/// the Keychain. Two people pair once, in person, and swap public keys. After that:
/// - every unlock request is signed by the person asking, so a Key Holder knows it is real;
/// - every answer is signed by the Key Holder, so a screenshot, a forwarded message or an old
///   answer cannot unlock anything (each answer covers one request id and one random nonce);
/// - the reason sent through iCloud is encrypted to the Key Holder, so only they can read it.
struct KeyPerson: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    let signingKey: Data      // P256 signing public key (raw)
    let agreementKey: Data    // P256 key agreement public key (raw)
}

/// What two phones swap when they pair.
struct KeyCard: Codable {
    let id: String
    let name: String
    let signingKey: Data
    let agreementKey: Data
}

@MainActor
final class KeyStore: ObservableObject {
    /// People who can let ME out.
    @Published private(set) var holders: [KeyPerson] = []
    /// People I can let out.
    @Published private(set) var friends: [KeyPerson] = []
    @Published var myName: String {
        didSet { UserDefaults.standard.set(myName, forKey: Self.nameKey) }
    }

    let myID: String
    private let signing: P256.Signing.PrivateKey
    private let agreement: P256.KeyAgreement.PrivateKey

    private static let holdersKey = "lockin.keys.holders.v1"
    private static let friendsKey = "lockin.keys.friends.v1"
    private static let nameKey = "lockin.keys.name.v1"
    private static let idKey = "lockin.keys.id.v1"

    init() {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: Self.idKey) { myID = id }
        else { myID = UUID().uuidString; defaults.set(myID, forKey: Self.idKey) }
        signing = Self.loadOrMake("lockin.keys.signing", make: { P256.Signing.PrivateKey() },
                                  read: { try P256.Signing.PrivateKey(rawRepresentation: $0) }, raw: { $0.rawRepresentation })
        agreement = Self.loadOrMake("lockin.keys.agreement", make: { P256.KeyAgreement.PrivateKey() },
                                    read: { try P256.KeyAgreement.PrivateKey(rawRepresentation: $0) }, raw: { $0.rawRepresentation })
        myName = defaults.string(forKey: Self.nameKey) ?? ""
        holders = Self.load(Self.holdersKey)
        friends = Self.load(Self.friendsKey)
    }

    var myCard: KeyCard {
        KeyCard(id: myID, name: myName.isEmpty ? "A friend" : myName,
                signingKey: signing.publicKey.rawRepresentation, agreementKey: agreement.publicKey.rawRepresentation)
    }

    func addHolder(_ card: KeyCard) {
        holders.removeAll { $0.id == card.id }
        holders.append(KeyPerson(id: card.id, name: card.name, signingKey: card.signingKey, agreementKey: card.agreementKey))
        Self.save(holders, Self.holdersKey)
    }

    func addFriend(_ card: KeyCard) {
        friends.removeAll { $0.id == card.id }
        friends.append(KeyPerson(id: card.id, name: card.name, signingKey: card.signingKey, agreementKey: card.agreementKey))
        Self.save(friends, Self.friendsKey)
    }

    func removeHolder(_ id: String) { holders.removeAll { $0.id == id }; Self.save(holders, Self.holdersKey) }
    func removeFriend(_ id: String) { friends.removeAll { $0.id == id }; Self.save(friends, Self.friendsKey) }

    // MARK: Signing

    func sign(_ text: String) -> Data {
        (try? signing.signature(for: Data(text.utf8)).rawRepresentation) ?? Data()
    }

    nonisolated static func verify(_ signature: Data, of text: String, by person: KeyPerson) -> Bool {
        guard let key = try? P256.Signing.PublicKey(rawRepresentation: person.signingKey),
              let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else { return false }
        return key.isValidSignature(sig, for: Data(text.utf8))
    }

    /// What the asker signs: who, which session, which request, and a one-time nonce.
    nonisolated static func requestText(requestID: String, from: String, to: String, sessionID: String, nonce: String) -> String {
        "lockin.ask|\(requestID)|\(from)|\(to)|\(sessionID)|\(nonce)"
    }

    /// What the Key Holder signs. It only fits the one request it answers.
    nonisolated static func answerText(requestID: String, nonce: String, approved: Bool) -> String {
        "lockin.answer|\(requestID)|\(nonce)|\(approved ? "yes" : "no")"
    }

    nonisolated static func newNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    // MARK: Encrypting the reason to one person

    /// Sealed with a fresh key agreed with the receiver's public key. Output: ephemeral key + box.
    nonisolated static func seal(_ text: String, to person: KeyPerson) -> Data? {
        guard let theirs = try? P256.KeyAgreement.PublicKey(rawRepresentation: person.agreementKey) else { return nil }
        let ephemeral = P256.KeyAgreement.PrivateKey()
        guard let shared = try? ephemeral.sharedSecretFromKeyAgreement(with: theirs) else { return nil }
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("lockin".utf8), sharedInfo: Data(), outputByteCount: 32)
        guard let box = try? AES.GCM.seal(Data(text.utf8), using: key).combined else { return nil }
        return ephemeral.publicKey.rawRepresentation + box
    }

    func open(_ sealed: Data) -> String? {
        let keyLength = 64
        guard sealed.count > keyLength,
              let eph = try? P256.KeyAgreement.PublicKey(rawRepresentation: sealed.prefix(keyLength)),
              let shared = try? agreement.sharedSecretFromKeyAgreement(with: eph) else { return nil }
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("lockin".utf8), sharedInfo: Data(), outputByteCount: 32)
        guard let box = try? AES.GCM.SealedBox(combined: sealed.dropFirst(keyLength)),
              let plain = try? AES.GCM.open(box, using: key) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    // MARK: Storage

    private static func load(_ key: String) -> [KeyPerson] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([KeyPerson].self, from: data)) ?? []
    }

    private static func save(_ people: [KeyPerson], _ key: String) {
        if let data = try? JSONEncoder().encode(people) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Private keys live in the Keychain, this device only.
    private static func loadOrMake<K>(_ account: String, make: () -> K, read: (Data) throws -> K, raw: (K) -> Data) -> K {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "lockin.keys",
                                    kSecAttrAccount as String: account, kSecReturnData as String: true]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data, let key = try? read(data) {
            return key
        }
        let key = make()
        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "lockin.keys",
                                  kSecAttrAccount as String: account, kSecValueData as String: raw(key),
                                  kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let old: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "lockin.keys",
                                  kSecAttrAccount as String: account]
        SecItemDelete(old as CFDictionary)
        SecItemAdd(add as CFDictionary, nil)
        return key
    }
}
