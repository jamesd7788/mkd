import Foundation

enum ConnectionStatus: String {
    case connected
    case reconnecting
    case disconnected
    case hidden
}

protocol FileSource: AnyObject {
    var onChange: (() -> Void)? { get set }
    var onConnectionStatus: ((ConnectionStatus) -> Void)? { get set }
    var displayName: String { get }
    var displayPath: String { get }
    var isRemote: Bool { get }

    func fetchContent() throws -> String
    func start()
    func stop()
}
