//
//  TestSwiftObject.swift
//  TestAudioOn6s
//
//  Created by Nguyen Tuan on 12/11/15.
//  Copyright © 2015 withfabric.io. All rights reserved.
//

import Foundation


class TestSwiftObject: NSObject {
    func playSound(name: String, type: String, loop: Bool, viberation:Bool) {
        if (name != "calling_01") {
            SystemSoundHelper.shareInstance().stopVibration()
        }
        SystemSoundHelper.shareInstance().playSoundWithName(name, type: type, loop: loop, withViberation: viberation)
    }
}