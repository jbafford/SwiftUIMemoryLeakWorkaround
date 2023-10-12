# SwiftUI Memory Leak Workaround


A workaround to a memory leak with SwiftUI sheets in iOS 17/macOS 14.

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Usage](#usage)
- [Examples](#examples)
- [TODO](#todo)
- [License](#license)


## The Problem

The new Observation framework in iOS 17 (and aligned macOS, tvOS, and watchOS releases) retains strong references to reference objects it is tracking. This appears to combine with an issue in SwiftUI that causes objects in views to not always be released when the view is dismissed.

This manifests when a SwiftUI view presents a `sheet` or `fullScreenCover` and the view captures an object. The object is retained by the system, but is not released when the presented view goes away.

For small view models, this may not be a problem, unless they're also tracking notifications or other external events.

Larger view models are the main problem; I discovered this issue when I noticed my app using several gigabytes of memory when it had no open windows.

This bug is present in at least iOS 17.0 .. 17.1b3.

This package provides a way to resolve the problem in a way that should be relatively backwards-compatible when the OS bug is eventually fixed.


## The Solution

The solution is to instead have `UIViewController` handle the presentation of sheets. This is accomplished by injecting a coordinator object into the SwiftUI environment that has a `UIViewController` that is the parent of the SwiftUI view. Then, the SwiftUI view is modified to call the coordinator, rather than `sheet` or `fullScreenCover` directly. The coordinator uses its stored view controller to present a new view, and creates a new coordinator to inject into the sheet view with the child view controller.

An extension on `View` provides accessors (`leak_workaround_sheet` and `leak_workaround_fullScreenCover`) that create a view modifier that uses the coordinator to trigger presentation. In the event the coordinator is not set or is set to `nil`, it falls back to the system behavior.

The included Example.xcodeproj demonstrates both the problem and the solution.

This is not a perfect solution. Sometimes, the coordinator itself is leaked. The coordinator object contains two weak references and an optional UUID, and so is relatively tiny compared to the view models that would likely be leaked instead.


## Usage

* Create a new `SwiftUIMemoryLeakWorkaround` coordinator
* Set its 
* Provide to SwiftUI via the environment, as `environment(\.swiftuiLeakWorkaround)`
* Instead of `sheet(item:, ...)` or `fullScreenCover(item:, ...)`, call `leak_workaround_sheet` and `leak_workaround_fullScreenCover`.
* Present your root SwiftUI view from UIKit.

Once the bug in the system is fixed, your application can test for the fixed version of the OS. In that case, you can set the environment value for the coordinator to `nil`, or simply not set it at all.


### Examples

#### Presentation Example

The nominal case, where you are presenting a SwiftUI view from UIKit:

```swift
let someUIViewController: UIViewController

let workaround = SwiftUIMemoryLeakWorkaround(viewController: someUIViewController)

let view = SomeSwiftUIView()
	.environment(\.swiftuiLeakWorkaround, workaround)

let controller = UIHostingController(rootView: view)

someUIViewController.present(controller, animated: true)
```


#### Presentation Example 2

Handling the case where a `UIHostingController` needs its view wrapped.

```swift
struct SwiftUIViewLeakWrapper : View {
	let workaround: SwiftUIMemoryLeakWorkaround
	
	var body: some View {
		SwiftUIView()
			.environment(\.swiftuiLeakWorkaround, workaround)
	}
}

final class SwiftUIViewController : UIHostingController<SwiftUIViewWrapper> {
	init() {
		let workaround = SwiftUIMemoryLeakWorkaround()
		
		super.init(rootView: SwiftUIViewLeakWrapper(workaround: workaround))
		
		workaround.controller = self
	}
}

// in another view controller
present(SwiftUIViewController(), animated: true)
```


#### SwiftUI View Example

```swift
@Observable final class SheetViewModel {
	let depth: Int
	
	init(_ depth: Int) {
		self.depth = depth
		print("• init")
	}
	
	deinit { print("• deinit") }
	
	func newChild() -> SheetViewModel {
		let child = SheetViewModel(depth + 1)
	}
}

struct SomeSwiftUIView : View {
	let viewModel: SheetViewModel
	
	@State var child: SheetViewModel?
	
	var body: some View {
		Button {
			child = viewModel.newChild()
		} label: {
			Label("Nest View \(viewModel.depth)")
		}
		.leak_workaround_sheet(item: $child) {
			SomeSwiftUIView(viewModel: child)
		}
	}
}
```


## TODO
* Blog post
* Docs: iOS < 17
* Add macOS (AppKit) support
* Add watchOS support
* Add tvOS support
* Add tests
* Confirm workaround does not cause issues in iOS < 17
* Test to see if `sheet(isPresented:)` and `fullScreenCover(isPresented:)` also have this problem, and add a wrapper if so.

If you would like to help out, please feel free to submit a PR.


## License

SwiftUIMemoryLeakWorkaround is released under the MIT License. [See LICENSE](https://github.com/jbafford/SwiftUIMemoryLeakWorkaround/blob/main/LICENSE) for details.
