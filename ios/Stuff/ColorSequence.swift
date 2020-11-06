//
//  ColorSequence.swift
//  Sequences
//
// Copyright (c) 2019 Chris Goldsby
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import UIKit


extension UIColor {
    
    /**
     Sequence that generates the `next` color using a Sine wave.
     - returns: `AnySequence<UIColor>`
     - parameter frequency: how fast the sine wave oscillates
     - parameter phase1: color phase in radians for red
     - parameter phase2: color phase in radians for green
     - parameter phase3: color phase in radians for blue
     - parameter amplitude: how high and low the sine wave reaches.
     - parameter center: the center position of the sine wave.
     - parameter repeat: if `true` the sequence will continue infinitely; defaults to false
     */
    public static func rainbowSequence(frequency:   CGFloat = Default.frequency,
                                       phase1:      CGFloat = Default.phase1,
                                       phase2:      CGFloat = Default.phase2,
                                       phase3:      CGFloat = Default.phase3,
                                       amplitude:   CGFloat = Default.amplitude,
                                       center:      CGFloat = Default.center,
                                       repeat:      Bool    = false) -> AnySequence<UIColor> {
        
        return AnySequence(rainbowIterator(frequency:  frequency,
                                           phase1:     phase1,
                                           phase2:     phase2,
                                           phase3:     phase3,
                                           amplitude:  amplitude,
                                           center:     center,
                                           repeat:     `repeat`))
    }
}
