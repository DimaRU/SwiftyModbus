//
//  CHelpers.swift
//
//
//  Created by Bastian Rössler on 19.10.23.
//

import Foundation

extension String {
    
    // Solution from https://stackoverflow.com/questions/36024295/how-to-convert-character-to-uint8-in-swift
    var byteArray : [CChar] {
        return String(self).utf8.map { value in
            CChar(value)
        }
    }
    
}

