
import Foundation

class MockClassTests: MockoloTestCase {
    
    func testMockClass() {
        verify(srcContent: klass,
               dstContent: klassMock)
    }
    
    func testMockClassWithParent() {
        verify(srcContent: klass,
               mockContent: klassParentMock,
               dstContent: klassLongerMock)
    }

    func testMockClassInits() {
        verify(srcContent: klassInit,
               dstContent: klassInitMock)
    }

    func testMockClassInitsWithParents() {
        verify(srcContent: klassInit,
               mockContent: klassInitParentMock,
               dstContent: klassInitLongerMock)
    }

    func testasdf() {
        verify(srcContent: a,
               dstContent: klassInitLongerMock,
               parser: .sourceKit)
    }
}


let a = """
/// @mockable
class X {
    typealias K = AnyObject
    func omg(arg: K) {}
}
"""

/// @mockable
class X {
    let m: String
    init(m: String) { self.m = m }
    class var mb: Int { return 3 }
    static var mbs: Int { return 3 }
}
class XX: X {
    override class var mb: Int { return 5 }  // <--- class member can be overriden, keep class keyword
//    override static var mbs: Int { return 3 }
}


let x = """
/// @mockable
class VoIPCallScreenViewable: View {
    func setCallState(state: String) {}
    func setOtherParticipant(name: String) {}
    func setMuteIcon(on: Bool) {}
    func setSpeakerIcon(on: Bool) {}
    func setEndCallIcon() {}
    weak var listener: VoIPCallScreenViewListener?
public let key: ModularMapSubviewKey
public let layoutManager: ModularMapSubviewLayoutManaging

}

"""

let xmock = """

class VoIPCallScreenViewableMock: VoIPCallScreenViewable {
    
        private var _doneInit = false
    
    init() { _doneInit = true }   // <---------- TODO: this needs override but doesn't generate it, why?
    

    public override var key: ModularMapSubviewKey {..} //<-- cannot override immutable 'let' property 'layoutManager' with the getter of a 'var'
    public override var layoutManager: ModularMapSubviewLayoutManaging {..} // <---attempt to override property here


        var setCallStateCallCount = 0
    var setCallStateHandler: ((String) -> ())?
    override func setCallState(state: String)  {
        setCallStateCallCount += 1

        if let setCallStateHandler = setCallStateHandler {
            setCallStateHandler(state)
        }
        
    }
    var setOtherParticipantCallCount = 0
    var setOtherParticipantHandler: ((String) -> ())?
    override func setOtherParticipant(name: String)  {
        setOtherParticipantCallCount += 1

        if let setOtherParticipantHandler = setOtherParticipantHandler {
            setOtherParticipantHandler(name)
        }
        
    }
    var setMuteIconCallCount = 0
    var setMuteIconHandler: ((Bool) -> ())?
    override func setMuteIcon(on: Bool)  {
        setMuteIconCallCount += 1

        if let setMuteIconHandler = setMuteIconHandler {
            setMuteIconHandler(on)
        }
        
    }
    var setSpeakerIconCallCount = 0
    var setSpeakerIconHandler: ((Bool) -> ())?
    override func setSpeakerIcon(on: Bool)  {
        setSpeakerIconCallCount += 1

        if let setSpeakerIconHandler = setSpeakerIconHandler {
            setSpeakerIconHandler(on)
        }
        
    }
    var setEndCallIconCallCount = 0
    var setEndCallIconHandler: (() -> ())?
    override func setEndCallIcon()  {
        setEndCallIconCallCount += 1

        if let setEndCallIconHandler = setEndCallIconHandler {
            setEndCallIconHandler()
        }
        
    }
    
    var listenerSetCallCount = 0
    var underlyingListener: VoIPCallScreenViewListener? = nil
    override var listener: VoIPCallScreenViewListener? {  // <----- should have weak 
        get { return underlyingListener }
        set {
            underlyingListener = newValue
            if _doneInit { listenerSetCallCount += 1 }
        }
    }
}
"""
