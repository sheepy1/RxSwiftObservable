//: Playground - noun: a place where people can play

import UIKit

//hack:因为Swift中没有抽象函数的概念，不能在函数前加abstract强制子类重写该方法，只能用这种不重写就抛出Error的方式来模拟
@noreturn func abstractMethod() -> Void {
    fatalError("Abstract method")
}

public protocol Disposable {
    func dispose()
}

enum Event<Element> {
    case Next(Element)
    case Error(ErrorType)
    case Completed
}

//MARK: - Observable
protocol ObservableType {
    typealias E
    
    func subscribe<O: ObserverType where O.E == E>(observer: O)
}

extension ObservableType {
    //一般都会调用这个subscribe方法，参数是一个闭包
    func subscribe(on: (event: Event<E>) -> Void)  {
        //构造一个匿名观察者，把参数on赋值给这个匿名观察者的eventHandler
        let observer = AnonymousObserver(on)
        self.subscribeSafe(observer)
    }
    
    func subscribeSafe<O: ObserverType where O.E == E>(observer: O) {
        //会调用被子类实现的的subscribe方法
        self.subscribe(observer)
    }
}

//基本相当于一个抽象类，提供了asObservable的实现。
class Observable<Element>: ObservableType {
    typealias E = Element
    
    func subscribe<O: ObserverType where O.E == E>(observer: O) {
        abstractMethod()
    }
    
    func asObservable() -> Observable<E> {
        return self
    }
}

//Empty,Just,Never都继承自Producer，都会重写run，在run中调用传入的观察者的on方法。
class Producer<Element> : Observable<Element> {
    //会被ObserverType的extension方法subscribeSafe调用
    override func subscribe<O : ObserverType where O.E == E>(observer: O) {
        //会有一些关于资源释放以及线程相关的操作
        //……
        run(observer)
    }
    
    func run<O : ObserverType where O.E == Element>(observer: O) {
        abstractMethod()
    }
    
}

class Empty<Element> : Producer<Element> {
    //run会在父类中被subscribe方法调用
    override func run<O : ObserverType where O.E == Element>(observer: O) {
        //观察者订阅了一个完成信号
        observer.on(.Completed)
    }
}

class Just<Element>: Producer<Element> {
    let element: Element
    
    init(element: Element) {
        self.element = element
    }
    
    override func run<O : ObserverType where O.E == Element>(observer: O) {
        observer.on(.Next(element))
        observer.on(.Completed)
    }
}

//MARK: - Observer
protocol ObserverType {
    //hack:因为Swift中没有范型协议，只能在协议中声明一个别名，
    //然后将实现类声明为范型类，再将传入的范型名命名为E（如typealias E = Element）
    typealias E
    
    func on(evet: Event<E>)
}

class ObserverBase<ElementType>: ObserverType {
    typealias E = ElementType
    
    var isStopped: Int32 = 0
    
    init() {
    }
    
    func on(event: Event<E>) {
        switch event {
        case .Next:
            if isStopped == 0 {
                onCore(event)
            }
        //一旦出现一次Error或Completed事件，之后也不会再执行onCore了
        case .Error, .Completed:
            //OSAtomicCompareAndSwap32:比较和交换的原子操作，如果isStopped == 0,则isStoppend = 1,返回true，否则返回false
            if !OSAtomicCompareAndSwap32(0, 1, &isStopped) {
                return
            }
            
            onCore(event)
        }
    }
    //会在子类中重写
    func onCore(event: Event<E>) {
        abstractMethod()
    }
}

class AnonymousObserver<ElementType> : ObserverBase<ElementType> {
    typealias Element = ElementType
    
    typealias EventHandler = Event<Element> -> Void
    
    private let eventHandler : EventHandler
    
    init(_ eventHandler: EventHandler) {
        //资源情况追踪（为了开发期解决内存泄漏问题吧）
        #if TRACE_RESOURCES
            //原子操作：resourceCount加1
            OSAtomicIncrement32(&resourceCount)
        #endif
        self.eventHandler = eventHandler
    }
    //onCore会被on调用（on继承自父类）
    override func onCore(event: Event<Element>) {
        return self.eventHandler(event)
    }
    
    #if TRACE_RESOURCES
    deinit {
    //原子操作：resourceCount减1
    OSAtomicDecrement32(&resourceCount)
    }
    #endif
}

//MARK: - 包装函数
func just<E>(element: E) -> Observable<E> {
    return Just(element: element)
}

func empty<E>() -> Observable<E> {
    return Empty<E>()
}

//MARK: - 调用
print("just observable demo:")
let justObservable = just(1)
justObservable.subscribe { event in
    print(event)
}

print("----")

print("empty observable demo:")
let emptyObservable: Observable<Int> = empty()
emptyObservable.subscribe { event in
    print(event)
}
