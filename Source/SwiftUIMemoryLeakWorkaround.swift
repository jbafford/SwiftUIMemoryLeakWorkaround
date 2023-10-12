//
//  SwiftUIMemoryLeakWorkaround.swift
//  SwiftUIMemoryLeakWorkaround
//
//  Created by John Bafford on 10/9/23.
//  Copyright © 2023 Longstride Tech LLC. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit


private struct LeakWorkaroundKey : EnvironmentKey {
	static let defaultValue: SwiftUIMemoryLeakWorkaround? = nil
}

public extension EnvironmentValues {
	var swiftuiLeakWorkaround: SwiftUIMemoryLeakWorkaround? {
		get { self[LeakWorkaroundKey.self] }
		set { self[LeakWorkaroundKey.self] = newValue }
	}
}


private struct Leak_Workaround_SwiftUIPresentation<Item : AnyObject & Identifiable & Equatable, Contents: View> : ViewModifier {
	@Environment(\.swiftuiLeakWorkaround) var avoider: SwiftUIMemoryLeakWorkaround?
	
	let type: SwiftUIMemoryLeakWorkaround.PresentationType
	let item: Binding<Item?>
	let onDismiss: (() -> Void)?
	let presentedView: (Item) -> Contents
	
	@State private var id = UUID()
	
	
	init(type: SwiftUIMemoryLeakWorkaround.PresentationType, item: Binding<Item?>, onDismiss: (() -> Void)? = nil, content: @escaping (Item) -> Contents) {
		self.type = type
		self.item = item
		self.onDismiss = onDismiss
		self.presentedView = content
	}
	
	func body(content: Content) -> some View {
		if #available(iOS 17.0, *), let avoider {
			content
				.onChange(of: item.wrappedValue) {
					avoider.present(type, id: id, item, onDismiss: onDismiss, content: presentedView)
				}
		} else {
			switch type {
			case .fullScreenCover:
				content
					.fullScreenCover(item: item, onDismiss: onDismiss, content: presentedView)
			
			case .sheet:
				content
					.sheet(item: item, onDismiss: onDismiss, content: presentedView)
			}
		}
	}
}

public extension View {
	func leak_workaround_sheet<Item : AnyObject & Identifiable & Equatable>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> some View) -> some View {
		modifier(Leak_Workaround_SwiftUIPresentation(type: .sheet, item: item, onDismiss: onDismiss, content: content))
	}
	
	func leak_workaround_fullScreenCover<Item : AnyObject & Identifiable & Equatable>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> some View) -> some View {
		modifier(Leak_Workaround_SwiftUIPresentation(type: .fullScreenCover, item: item, onDismiss: onDismiss, content: content))
	}
}


/// A manager class for working around SwiftUI in iOS 17 leaking classes passed into a sheet or fullScreenCover presentation.
///
/// Present your root SwiftUI view from a `UIHostingController`, with a new `SwiftUIMemoryLeakWorkaround` added to the enviromennt:
///
/// ```
/// let workaround = SwiftUIMemoryLeakWorkaround()
/// view
/// 	.environment(\.swiftuiLeakWorkaround, workaround)
/// ```
///
/// After creating the coordinator, set its `controller` to the `UIViewController` that will contain your SwiftUI view.
/// Note that the controller is not provided in init to allow for two-phase initialization, such as is required when the
/// SwiftUI view is defined in an `init` method of a `UIHostingController` subclass.
///
/// In your SwiftUI views, replace calls to `.sheet` and `.fullScreenCover` with `.leak_workaround_sheet` and `.leak_workaround_fullScreenCover`.
///
/// The `item` provided to `.leak_workaround_sheet` and `.leak_workaround_fullScreenCover` must be
/// `Equatable` (in addition to `Identifiable`). This is because the workaround uses `.onChange(of:)` to detect changes,
/// and that view modifier requires `Equatable`.
///
/// Prior to iOS 17, or if the `\.swiftuiLeakWorkaround` environment key is not set, or set to `nil`, the workaround will have
/// no effect, and SwiftUI's sheet or fullScreenCover will be called. If the memory leak is fixed, in your application code,
/// you can then test for this fixed version of iOS and either not set the key, or set it to `nil`.
public final class SwiftUIMemoryLeakWorkaround {
	enum PresentationType {
		case sheet
		case fullScreenCover
	}
	
	/// The controller that we should present to.
	public weak var controller: UIViewController?
	
	/// An id of the source presentation request, used to disambiguate multiple sheet requests on the same view.
	private var source: UUID?
	
	/// The controller that is presented.
	private weak var childController: UIViewController?
	
	
	public init(viewController: UIViewController? = nil) {
		self.controller = viewController
	}
	
	func present<T : AnyObject>(_ type: PresentationType, id: UUID, _ item: Binding<T?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: (T) -> some View) {
		guard let controller else { return }
		
		let sameSource = id == source
		
		switch (sameSource, item.wrappedValue) {
		case (false, .none):
			//A different sheet request had its truth cleared.
			//Nothing to do.
			break
		
		case (true, .none):
			//The current sheet request had its truth cleared.
			//Dismiss the current sheet.
			childController?.dismiss(animated: true)
			childController = nil
			source = nil
			break
		
		case (_, .some(let truth)):
			// If sameSource, then the current sheet request had its truth changed.
			// Dismiss the current sheet with no animation, replacing it with the new value with no animation.
			//
			// Else, a different sheet request has had its value set.
			// Dismiss the current sheet, with animation, and present the new one, with animation.
			childController?.dismiss(animated: !sameSource)
			childController = nil
			
			// Create a new presentation coordinator for the next level of nesting.
			// That way each coordinator doesn't have to understand the nested view structure.
			// Note that SwiftUI might still leak the presentation coordinator, because it gets captured in the environment,
			// but at worst, that just means the size of two pointers, a UUID, and the ObservableObject subject and publisher.
			let child = SwiftUIMemoryLeakWorkaround()
			
			let view = content(truth)
				.environment(\.swiftuiLeakWorkaround, child)
				.onDisappear(perform: { [weak self] in
					// Use the binding to set the source to nil, like SwiftUI would when the sheet is dismissed.
					item.wrappedValue = nil
					
					//Then clear our references to the child controller and tracking id
					self?.childController = nil
					self?.source = nil
					
					//Finally, call the onDismiss, if any
					onDismiss?()
				})
			
			let childController = UIHostingController(rootView: view)
			child.controller = childController
			
			self.source = id
			self.childController = childController
			
			switch type {
			case .sheet:
				childController.modalPresentationStyle = .formSheet
			
			case .fullScreenCover:
				childController.modalPresentationStyle = .fullScreen
			}
			
			controller.present(childController, animated: true)
		}
	}
}
