# SwiftUI Leak Workaround


A workaround to a memory leak with SwiftUI sheets in iOS 17/macOS 14.

- [The Problem](#the-problem)
- [Usage](#usage)
- [TODO](#todo)
- [License](#license)


## The Problem

The new Observation framework in iOS 17 (and aligned macOS, tvOS, and watchOS platforms) retains strong references to reference objects it is tracking. This appears to combine with an issue in SwiftUI that causes objects in views to not always be released when the view is dismissed.

This manifests when a SwiftUI view presents a `sheet` or `fullScreenCover` and the view captures an object. The object is retained by the system, but is not released when the presented view goes away.

For small view models, this may not be a problem, unless they're also tracking notifications or other external events.

Larger view models are the main problem; I discovered this issue when I noticed my app using several gigabytes of memory when it had no open windows.

This bug is present in at least iOS 17.0 .. 17.1b3.

This package provides a way to resolve the problem in a way that should be relatively backwards-compatible when the OS bug is eventually fixed.


## Usage

* Create a new `SwiftUIMemoryLeakWorkaround` coordinator
* Set its 
* Provide to SwiftUI via the environment, as `environment(\.swiftuiLeakWorkaround)`
* Instead of `sheet(item:, ...)` or `fullScreenCover(item:, ...)`, call `leak_workaround_sheet` and `leak_workaround_fullScreenCover`.
* Present your root SwiftUI view from UIKit.


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
struct SomeSwiftUIView : View {
	let viewModel: SomeSwiftUIViewModel
	let depth: Int
	
	let item: SomeSwiftUIViewModel?
	
	var body: some View {
		Button {
			item = viewModel
		} label: {
			Label("Nest View \(depth)")
		}
		.leak_workaround_sheet(item: $item) {
			SomeSwiftUIView(viewModel: viewModel, depth: depth + 1)
		}
	}
}
```


## TODO
* Blog post
* Docs: iOS < 17; what to do when the OS bug is fixed
* Add macOS (AppKit) support
* Add watchOS support
* Add tvOS support
* Add tests
* Confirm workaround does not cause issues in iOS < 17
* Test to see if `sheet(isPresented:)` and `fullScreenCover(isPresented:)` also have this problem, and add a wrapper if so.

If you would like to help out, please feel free to submit a PR.


## License

SwiftUIMemoryLeakWorkaround is released under the MIT License. [See LICENSE](https://github.com/jbafford/SwiftUIMemoryLeakWorkaround/blob/main/LICENSE) for details.
