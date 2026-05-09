import Foundation
import SwiftData

@Model
final class PayloadBlob {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    @Attribute(.externalStorage) var data: Data
    var item: ClipItem?

    init(id: UUID = UUID(), typeRawValue: String, data: Data, item: ClipItem? = nil) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.data = data
        self.item = item
    }
}
