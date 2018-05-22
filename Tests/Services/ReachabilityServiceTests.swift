//
//  ReachabilityServiceTests.swift
//  ModernAVPlayer_Tests
//
//  Created by raphael ankierman on 30/04/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import AVFoundation
import Quick
@testable
import ModernAVPlayer
import Nimble

final class ReachabilityServiceTests: QuickSpec {
    
    var tested: ReachabilityServiceProtocol!
    var config: ContextConfiguration!
    var isReachable: Bool?
    var mockTimerFactory: MockTimerFactory!
    var dataTaskFactory: MockDataTaskFactory!
    
    override func spec() {
        
        beforeEach {
            self.dataTaskFactory = MockDataTaskFactory()
            self.mockTimerFactory = MockTimerFactory()
            self.config = PlayerContextConfiguration()
            self.tested = ReachabilityService(config: self.config, dataTaskFactory: self.dataTaskFactory, timerFactory: self.mockTimerFactory)
            self.tested.isReachable = { [weak self] reachableStatus in self?.isReachable = reachableStatus }
        }
        
        describe("deinit service") {
            it("should invalidate timer") {
                
                // ACT - closure used to deinit the instance
                {
                    let service = ReachabilityService(config: self.config, dataTaskFactory: self.dataTaskFactory, timerFactory: self.mockTimerFactory)
                    service.start()
                }()
                
                
                // ASSERT
                expect(self.mockTimerFactory.timer.invalidate_CallCount).to(equal(1))
            }
            
            it("should cancel pending network task") {
                
                // ACT - closure used to deinit the instance
                {
                    let service = ReachabilityService(config: self.config, dataTaskFactory: self.dataTaskFactory, timerFactory: self.mockTimerFactory)
                    service.start()
                    self.mockTimerFactory.lastCompletion?()
                }()
                
                // ASSERT
                expect(self.dataTaskFactory.dataTask.cancel_CallCount).to(equal(1))
            }
        }
        
        describe("start service") {
            it("should fire timer ") {
                
                // ACT
                self.tested.start()
                
                // ASSERT
                expect(self.mockTimerFactory.timer.fire_CallCount).to(equal(1))
            }
            
            context("max network iteration reach") {
                it("should invalidate timer") {
                    
                    // ACT
                    self.tested.start()
                    let maxIterationAvailable = self.config.networkIteration
                    (0..<maxIterationAvailable).forEach { _ in
                        self.mockTimerFactory.lastCompletion?()
                    }
                    
                    // ASSERT
                    expect(self.mockTimerFactory.timer.invalidate_CallCount).to(equal(1))
                }
            }
            
            context("max network iteration not reach") {
                it("should not invalidate timer") {
                    
                    // ACT
                    self.tested.start()
                    let maxIterationAvailable = self.config.networkIteration - 1
                    var iteration = 0
                    
                    while iteration < maxIterationAvailable {
                        self.mockTimerFactory.lastCompletion?()
                        iteration += 1
                    }
                    
                    // ASSERT
                    expect(self.mockTimerFactory.timer.invalidate_CallCount).to(equal(0))
                }
            }
            
            context("network iteration") {
                it("should resume network task") {
                    
                    // ACT
                    self.tested.start()
                    self.mockTimerFactory.lastCompletion?()
                    
                    // ASSERT
                    expect(self.dataTaskFactory.dataTask.resume_CallCount).to(equal(1))
                }
            }
            
            context("request succeed") {
                it("should invalidate timer") {
                    
                    // ACT
                    self.tested.start()
                    self.mockTimerFactory.lastCompletion?()
                    let httpResponse = HTTPURLResponse(url: URL(string: "foo")!, statusCode: 200, httpVersion: nil, headerFields: nil)
                    self.dataTaskFactory.lastCompletionHandler?(nil, httpResponse, nil)
                    
                    // ASSERT
                    expect(self.mockTimerFactory.timer.invalidate_CallCount).to(equal(1))
                }
                it("should set isReachable to true") {
                    
                    // ACT
                    self.tested.start()
                    self.mockTimerFactory.lastCompletion?()
                    let httpResponse = HTTPURLResponse(url: URL(string: "foo")!, statusCode: 200, httpVersion: nil, headerFields: nil)
                    self.dataTaskFactory.lastCompletionHandler?(nil, httpResponse, nil)
                    
                    // ASSERT
                    expect(self.isReachable).to(beTrue())
                }
            }
            
            context("request failed") {
                it("should set isReachable to false") {
                    
                    // ACT
                    self.tested.start()
                    self.mockTimerFactory.lastCompletion?()
                    let httpResponse = HTTPURLResponse(url: URL(string: "foo")!, statusCode: 404, httpVersion: nil, headerFields: nil)
                    self.dataTaskFactory.lastCompletionHandler?(nil, httpResponse, nil)
                    
                    // ASSERT
                    expect(self.isReachable).to(beFalse())
                }
            }
        }
    }
}