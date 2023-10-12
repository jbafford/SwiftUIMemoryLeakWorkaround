//
//  ContentView.swift
//  SwiftUIMemoryLeakWorkaround
//
//  Created by John Bafford on 10/12/23.
//  Copyright © 2023 Longstride Tech LLC. All rights reserved.
//

import SwiftUI
import UIKit


@Observable final class SheetViewModel : Identifiable, Equatable {
	let depth: Int
	
	init(_ depth: Int) {
		self.depth = depth
		print("• init")
	}
	
	deinit { print("• deinit") }
	
	func newChild() -> SheetViewModel {
		return SheetViewModel(depth + 1)
	}
	
	static func == (lhs: SheetViewModel, rhs: SheetViewModel) -> Bool {
		return lhs === rhs
	}
}



struct RootViewContent: View {
	@Environment(\.dismiss) private var dismiss
	
	let viewModel: SheetViewModel
	
	@State private var leak: SheetViewModel?
	@State private var workaround: SheetViewModel?
	
	
    var body: some View {
        VStack {
			if viewModel.depth >= 1 {
				Text("Depth: \(viewModel.depth)")
				Button {
					dismiss()
				} label: {
					Text("Dismiss")
				}
			}
			
			Spacer()
			
			Button {
				leak = viewModel.newChild()
			} label: {
				Text("Open a sheet")
			}
			
			Spacer()
			
			Button {
				workaround = viewModel.newChild()
			} label: {
				Text("Open a sheet with the leak workaround")
			}
        }
        .padding()
        .sheet(item: $leak) { viewModel in
			RootViewContent(viewModel: viewModel)
        }
        .leak_workaround_sheet(item: $workaround) { viewModel in
			RootViewContent(viewModel: viewModel)
        }
    }
}

struct RootView : UIViewControllerRepresentable {
	func makeUIViewController(context: Context) -> some UIViewController {
		
		let workaround = SwiftUIMemoryLeakWorkaround()
		
		let view = RootViewContent(viewModel: SheetViewModel(0))
			.environment(\.swiftuiLeakWorkaround, workaround)
		
		let vc = UIHostingController(rootView: view)
		
		workaround.controller = vc
		
		return vc
	}
	
	func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
	}
}
