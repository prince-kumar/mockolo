import MockoloFramework

let rxMultiParents =
"""
/// \(String.mockAnnotation)
public protocol MutableDriverTasksStream: DriverTasksStream {
    func update(tasks: DriverTasks)
}

public protocol DriverTasksStream: TaskScopeListStream, JobTaskScopeListStream, DriverStateStream, DriverOnlineStream, DriverCompletionTasksStream, DriverJobStateStream {
    var tasks: Observable<DriverTasks> { get }
}

/// \(String.mockAnnotation)(rx: all = ReplaySubject)
public protocol TaskScopeListStream: AnyObject {
    /// Observable of an array of task scopes. This observable replays the most recent array.
    /// Emissions of this observable are guaranteed to be unique.
    var taskScopes: Observable<[TaskScope]> { get }
}

/// \(String.mockAnnotation)(rx: all = ReplaySubject)
public protocol JobTaskScopeListStream: AnyObject {
    /// Observable of an array of task scopes, filtered to only include scopes that are derived from
    /// a job in Demand. This observable replays the most recent array. Emissions of this observable
    /// are guaranteed to be unique.
    var jobTaskScopes: Observable<[TaskScope]> { get }
}

/// \(String.mockAnnotation)
public protocol DriverOnlineStream: AnyObject {
    var driverOnline: Observable<Bool> { get }
}
/// \(String.mockAnnotation)
public protocol DriverStateStream: AnyObject {
    var driverState: Observable<DriverState> { get }
}

/// \(String.mockAnnotation)(rx: all = BehaviorSubject)
public protocol DriverJobStateStream: AnyObject {
    var isOnJob: Observable<Bool> { get }
}

/// \(String.mockAnnotation)(rx: all = BehaviorSubject)
public protocol DriverCompletionTasksStream: AnyObject {
    var completionTasks: Observable<[DriverCompletionTask]> { get }
}

"""


let rxVarInherited =
"""
/// \(String.mockAnnotation)(rx: all = BehaviorSubject)
public protocol X {
    var myKey: Observable<SomeKey?> { get }
}

/// \(String.mockAnnotation)
public protocol Y: X {
    func update(with key: SomeKey)
}
"""

let rxVarInheritedMock = """
public class XMock: X {
    
    private var _doneInit = false
    
    public init() { _doneInit = true }
    public init(myKey: Observable<SomeKey?>) {
        self.myKey = myKey
        _doneInit = true
    }
    public var myKeySubjectSetCallCount = 0
    public var myKeyBehaviorSubject: BehaviorSubject<SomeKey?>! { didSet { if _doneInit { myKeySubjectSetCallCount += 1 } } }
    public var myKey: Observable<SomeKey?> {
        get { return myKeyBehaviorSubject }
        set { if let val = newValue as? BehaviorSubject<SomeKey?> { myKeyBehaviorSubject = val } }
    }
}

public class YMock: Y {
    
    private var _doneInit = false
    
    public init() { _doneInit = true }
    public init(myKey: Observable<SomeKey?> = PublishSubject<SomeKey?>()) {
        self.myKey = myKey
        _doneInit = true
    }
    public var myKeySubjectSetCallCount = 0
    public var myKeyBehaviorSubject: BehaviorSubject<SomeKey?>! { didSet { if _doneInit { myKeySubjectSetCallCount += 1 } } }
    public var myKey: Observable<SomeKey?> {
        get { return myKeyBehaviorSubject }
        set { if let val = newValue as? BehaviorSubject<SomeKey?> { myKeyBehaviorSubject = val } }
    }
    public var updateCallCount = 0
    public var updateHandler: ((SomeKey) -> ())?
    public func update(with key: SomeKey)  {
        updateCallCount += 1
        
        if let updateHandler = updateHandler {
            updateHandler(key)
        }
        
    }
}
"""

let rx = """
/// \(String.mockAnnotation)(rx: blockedByAttachedRouter = BehaviorSubject)
protocol ReactiveEMobilityRoutingInternal: EMobilityRouting {
    var blockedByAttachedRouter: Observable<Bool> { get }
    func embedModularMap()
    func detachModularMap()
    func routeToStartSteps(steps: [RealtimeEMobility.Step], providerUuid: String) -> Observable<()>
    func routeAwayFromStartSteps() -> Observable<()>
    func routeToPostRental(finishedRental: BookingV2) -> Observable<()>
    func routeAwayFromPostRental() -> Observable<()>
    func routeToIOSSettings()
    func routeToMainStateSearch() -> Observable<()>
    func routeToMainStateActive() -> Observable<()>
    func routeAwayFromMainState() -> Observable<()>
}


"""

let rxVarBehavior =
"""
/// \(String.mockAnnotation)(rx: nameStream = BehaviorSubject; some = ReplaySubject)
protocol RxVar {
    var isEnabled: Observable<Bool> { get }
    var nameStream: Observable<[EMobilitySearchVehicle]> { get }
    var intStream: Observable<Int> { get }
}
"""

let rxVarBehaviorMock =
"""
/// \(String.mockAnnotation)(rx: nameStream = BehaviorSubject)
protocol RxVar {
var nameStream: Observable<String> { get }
    var nameStream: Observable<String> { get }
}
"""


let rxVar =
"""
/// \(String.mockAnnotation)
protocol RxVar {
coreLocation: RxSwift.Observable<UBCoreLocation?>
}
"""
//var var nameStream: Observable<String> { get }

let rxVarMock =
"""
class RxVarMock: RxVar {

private var _doneInit = false
init() { _doneInit = true }
init(nameStream: Observable<String> = PublishSubject()) {
self.nameStream = nameStream
_doneInit = true
}

//private var nameStreamSubjectKind = 0
var nameStreamSubjectSetCallCount = 0
var nameStreamSubject = PublishSubject<String>() { didSet { if _doneInit { nameStreamSubjectSetCallCount += 1 } } }
//var nameStreamReplaySubject = ReplaySubject<String>.create(bufferSize: 1) { didSet { if _doneInit { nameStreamSubjectSetCallCount += 1 } } }
//var nameStreamBehaviorSubject: BehaviorSubject<String>! { didSet { if _doneInit { nameStreamSubjectSetCallCount += 1 } } }
//var nameStreamRxSubject: Observable<String>! { didSet { if _doneInit { nameStreamSubjectSetCallCount += 1 } } }
var nameStream: Observable<String> {
get {
//if nameStreamSubjectKind == 0 {
return nameStreamSubject
//} else if nameStreamSubjectKind == 1 {
//return nameStreamBehaviorSubject
//} else if nameStreamSubjectKind == 2 {
//return nameStreamReplaySubject
//} else {
//return nameStreamRxSubject
//}
}
set {
if let val = newValue as? PublishSubject<String> {
nameStreamSubject = val
//nameStreamSubjectKind = 0
}
//else if let val = newValue as? BehaviorSubject<String> {
//nameStreamBehaviorSubject = val
//nameStreamSubjectKind = 1
//} else if let val = newValue as? ReplaySubject<String> {
//nameStreamReplaySubject = val
//nameStreamSubjectKind = 2
//} else {
//nameStreamRxSubject = newValue
//nameStreamSubjectKind = 3
}
}
}
}

"""

