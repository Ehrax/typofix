import Foundation

enum RewriteVariantID: Hashable {
    case loading
    case concise
    case polished
    case shorter
    case friendlier
    case formal
    case instruction
}

struct RewriteVariant: Hashable {
    let id: RewriteVariantID
    let title: String
    var result: String?
    var isLoading: Bool
    var errorText: String?
}
