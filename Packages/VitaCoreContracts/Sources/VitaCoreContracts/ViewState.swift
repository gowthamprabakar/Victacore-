import Foundation

/// Represents the lifecycle state of a view's data.
public enum ViewState<T: Sendable>: Sendable {
    case loading
    case data(T)
    case empty
    case error(Error)
    case stale(T, age: TimeInterval)

    /// Returns `true` when data is being fetched.
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// Returns the underlying content if available (data or stale).
    public var content: T? {
        switch self {
        case .data(let value):        return value
        case .stale(let value, _):   return value
        default:                      return nil
        }
    }

    /// Returns `true` when the content is stale.
    public var isStale: Bool {
        if case .stale = self { return true }
        return false
    }

    /// Returns the associated error, if any.
    public var error: Error? {
        if case .error(let err) = self { return err }
        return nil
    }

    /// Returns `true` when the state holds no content and is not loading.
    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
