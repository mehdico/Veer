import Foundation
import Testing
@testable import Veer

@MainActor
struct PanelKeyHandlerTests {
    @Test func isPrintableRejectsControlCharactersAndDel() {
        let del = Character(Unicode.Scalar(0x7F)!)
        let backspace = Character(Unicode.Scalar(0x08)!)
        let nul = Character(Unicode.Scalar(0x00)!)
        let c1 = Character(Unicode.Scalar(0x9F)!)
        #expect(PanelKeyHandler.isPrintable(del) == false)
        #expect(PanelKeyHandler.isPrintable(backspace) == false)
        #expect(PanelKeyHandler.isPrintable(nul) == false)
        #expect(PanelKeyHandler.isPrintable(c1) == false)
    }

    @Test func isPrintableAcceptsTypicalCharactersAndSpace() {
        for ch in "abcXYZ 1!@#$%é漢" {
            #expect(PanelKeyHandler.isPrintable(ch) == true, "Expected printable: \(ch)")
        }
    }
}
