//
//  SearchBar.swift
//  ToDoList
//
//  Created by Simon Ng on 15/4/2020.
//  Copyright © 2020 AppCoda. All rights reserved.
//

import SwiftUI

///// https://stackoverflow.com/questions/56490963/how-to-display-a-search-bar-with-swiftui
//struct SearchBar: View {
//    @Binding var text: String
//
//    @State private var isEditing = false
//
//    var body: some View {
//        HStack {
//            HStack {
//                Image(systemName: "magnifyingglass")
//                    .foregroundColor(.gray).padding(.leading)
//                TextField("Search...", text: $text, onEditingChanged: { isEditing in
//                    self.isEditing = isEditing
//                }, onCommit: {})
//                .padding(7)
//                if isEditing && !text.isEmpty{
//                    Button(action: {
//                        self.text = ""
//                    }) {
//                        Image(systemName: "multiply.circle.fill")
//                            .foregroundColor(.gray)
//                    }.buttonStyle(BorderlessButtonStyle()).padding(.trailing)
//                }
//            }.background(Color(.systemGray6))
//            .cornerRadius(8)
//            .padding(.horizontal, 10)
//
//            if isEditing {
//                Button("Cancel") {
//                    self.isEditing = false
//                    self.text = ""
//
//                    // Dismiss the keyboard
//                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                }.buttonStyle(BorderlessButtonStyle()).foregroundColor(.accentColor)
//                .transition(.move(edge: .trailing))
//                .animation(.default)
//            }
//        }
//    }
//}

//
//  SearchBar.swift
//  SwiftUI_Search_Bar_in_Navigation_Bar
//
//  Created by Geri Borbás on 2020. 04. 27..
//  Copyright © 2020. Geri Borbás. All rights reserved.
//

///https://github.com/Geri-Borbas/iOS.Blog.SwiftUI_Search_Bar_in_Navigation_Bar/tree/02af72f81c791e8166f6b1f2fc6f0c1b6c7bcebe

import SwiftUI

//
//  ViewControllerResolver.swift
//  SwiftUI_Search_Bar_in_Navigation_Bar
//
//  Created by Geri Borbás on 2020. 04. 27..
//  Copyright © 2020. Geri Borbás. All rights reserved.
//

import SwiftUI

final class ViewControllerResolver: UIViewControllerRepresentable {
    
    let onResolve: (UIViewController) -> Void
        
    init(onResolve: @escaping (UIViewController) -> Void) {
        self.onResolve = onResolve
    }
    
    func makeUIViewController(context: Context) -> ParentResolverViewController {
        ParentResolverViewController(onResolve: onResolve)
    }
    
    func updateUIViewController(_ uiViewController: ParentResolverViewController, context: Context) { }
}

class ParentResolverViewController: UIViewController {
    
    let onResolve: (UIViewController) -> Void
    
    init(onResolve: @escaping (UIViewController) -> Void) {
        self.onResolve = onResolve
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Use init(onResolve:) to instantiate ParentResolverViewController.")
    }
        
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        if let parent = parent {
            onResolve(parent)
        }
    }
}


//
//  SearchBar.swift
//  SwiftUI_Search_Bar_in_Navigation_Bar
//
//  Created by Geri Borbás on 2020. 04. 27..
//  Copyright © 2020. Geri Borbás. All rights reserved.
//

import SwiftUI

class SearchBar: NSObject, ObservableObject {
    
    @Published var text: String = ""
    let searchController: UISearchController = UISearchController(searchResultsController: nil)
    
    override init() {
        super.init()
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchResultsUpdater = self
    }
}

extension SearchBar: UISearchResultsUpdating {
   
    func updateSearchResults(for searchController: UISearchController) {
        
        // Publish search bar text changes.
        if let searchBarText = searchController.searchBar.text {
            self.text = searchBarText
        }
    }
}

struct SearchBarModifier: ViewModifier {
    
    let searchBar: SearchBar
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ViewControllerResolver { viewController in
                    viewController.navigationItem.searchController = self.searchBar.searchController
                }
                    .frame(width: 0, height: 0)
            )
    }
}

extension View {
    
    func add(_ searchBar: SearchBar) -> some View {
        return self.modifier(SearchBarModifier(searchBar: searchBar))
    }
}



//struct SearchBar_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchBar(text: .constant(""))
//    }
//}
