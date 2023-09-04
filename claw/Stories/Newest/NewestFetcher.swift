//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

@MainActor
class NewestFetcher: ObservableObject {
    @Published var stories = NewestFetcher.cachedStories
    static var cachedStories = [NewestStory]()
    @Published var isLoadingMore = false
    @Published var isReloading = false
    var page: Int = 1
    
    init() {
        load()
    }
    
    static var shared = NewestFetcher()
    
    deinit {
        self.session?.cancel()
        self.moreSession?.cancel()
    }
    
    private var session: URLSessionTask? = nil
    private var moreSession: URLSessionTask? = nil
    
    func reload(completion: ((Error?)->Void)? = nil) {
        self.session?.cancel()
        self.isReloading = true
        self.page = 1
        self.load(completion: { error in
            self.isReloading = false
            completion?(error)
        })
    }

    func refresh() async throws {
        self.session?.cancel()
        self.page = 1
        self.isReloading = true
        try await withCheckedThrowingContinuation { continuation in
            self.load { error in
                DispatchQueue.main.async {
                    self.isReloading = false
                    if error == nil {
                        continuation.resume()
                        return
                    }
                    if let error {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func load(completion: ((Error?)->Void)? = nil) {
        let url = URL(string: "https://lobste.rs/newest.json?page=\(self.page)")!
        self.session = URLSession.shared.dataTask(with: url) {(data,response,error) in
            do {
                if let d = data {
                    let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                    DispatchQueue.main.async {
                        NewestFetcher.cachedStories = decodedLists
                        self.stories = decodedLists
                        self.page += 1
                        completion?(nil)
                    }
                }else {
                    print("No Data")
                    completion?(nil) // todo: throw error
                }
            } catch {
                print ("Error fetching newest \(error)")
                completion?(error)
            }
        }
        self.session?.resume()
    }
    
    func more(_ story: NewestStory? = nil, completion: ((Error?)->Void)? = nil) {
        if self.stories.last == story && !isLoadingMore {
            let url = URL(string: "https://lobste.rs/newest.json?page=\(self.page)")!
            self.isLoadingMore = true

            self.moreSession = URLSession.shared.dataTask(with: url) { (data,response,error) in
                do {
                    if let d = data {
                        let decodedLists = try JSONDecoder().decode([NewestStory].self, from: d)
                        DispatchQueue.main.async {
                            let stories = decodedLists
                            for story in stories {
                                if !self.stories.contains(story) {
                                    self.stories.append(story)
                                }
                            }
                            NewestFetcher.cachedStories = self.stories
                            self.page += 1
                            completion?(nil)
                        }
                    }else {
                        print("No Data")
                        completion?(nil) // todo: actually do error
                    }
                } catch {
                    print ("Error fetching newest more \(error)")
                    completion?(error)
                }
                DispatchQueue.main.async {
                    self.isLoadingMore = false
                }
            }
            self.moreSession?.resume()
        }
    }
}
