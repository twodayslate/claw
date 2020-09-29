//
//  StoryListView.swift
//  claw
//
//  Created by Zachary Gorak on 9/28/20.
//

import SwiftUI

struct PopupNavigationView<Content: View>: View {
    var content: () -> Content
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        NavigationView {
            self.content().navigationBarItems(trailing:
                                                Button(action: {
                                                    self.presentationMode.wrappedValue.dismiss()
                                                }, label: {
                                                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.systemGray4))
                                                }))
        }
    }
}
struct StoryListView: View {
    
    @AppStorage("StoryListViewStoryType") var storyType: Int = 0
    
    @State var showSettings = false
    @State var viewIsShown = true
    @GestureState private var dragState: Int = 0
    var body: some View {
        ZStack(alignment: .top) {
            if storyType == 0 {
                HottestView()
            } else {
                NewestView()
            }
            if viewIsShown {
                Picker(selection: $storyType, label: Text("Story Type"), content: {
                Text("Hottest").tag(0)
                Text("Newest").tag(1)
                }).pickerStyle(SegmentedPickerStyle()).padding().background(Color(UIColor.systemBackground).blur(radius: 15)).zIndex(1)
            }
        }.simultaneousGesture(DragGesture().onChanged({ transition in
            
            print(transition, transition.translation, transition.predictedEndTranslation)
            if transition.translation.height > 0 {
                withAnimation {
                    viewIsShown = true
                }
            } else {
                withAnimation {
                    viewIsShown = false
                }
            }
        })).navigationBarItems(trailing: Button(action: {
                     self.showSettings = true
                 }, label: {
                     Image(systemName: "gear")
                 })).sheet(isPresented: $showSettings, content: {
                    PopupNavigationView {
                        SettingsView()
                    }
                 })
    }
}

struct StoryListView_Previews: PreviewProvider {
    static var previews: some View {
        StoryListView()
    }
}
