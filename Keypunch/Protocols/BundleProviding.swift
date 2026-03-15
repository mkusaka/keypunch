import Foundation

protocol BundleProviding {
    var bundleIdentifier: String? { get }
}

extension Bundle: BundleProviding {}
