import Foundation

/// Describes errors that can occur during image-based recipe scanning.
enum ScanError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("error_invalid_image", comment: "")
        case .noTextFound:
            return NSLocalizedString("error_no_text_found", comment: "")
        }
    }
}
