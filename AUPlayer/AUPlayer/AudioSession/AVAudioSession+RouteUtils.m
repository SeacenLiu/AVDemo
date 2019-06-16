//
//  AVAudioSession+RouteUtils.m
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/13.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "AVAudioSession+RouteUtils.h"

@implementation AVAudioSession (RouteUtils)

- (BOOL)usingBlueTooth {
    NSArray *inputs = self.currentRoute.inputs;
    NSArray *blueToothInputRoutes = @[AVAudioSessionPortBluetoothHFP];
    for (AVAudioSessionPortDescription *description in inputs) {
        if ([blueToothInputRoutes containsObject:description.portType]) {
            return YES;
        }
    }
    
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *blueToothOutputRoutes = @[AVAudioSessionPortBluetoothHFP,
                                       AVAudioSessionPortBluetoothA2DP,
                                       AVAudioSessionPortBluetoothLE];
    for (AVAudioSessionPortDescription *description in outputs) {
        if ([blueToothOutputRoutes containsObject:description.portType]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)usingWiredMicrophone {
    NSArray *inputs = self.currentRoute.inputs;
    NSArray *headSetInputRoutes = @[AVAudioSessionPortHeadsetMic];
    for (AVAudioSessionPortDescription *description in inputs) {
        if ([headSetInputRoutes containsObject:description.portType]) {
            return YES;
        }
    }
    
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *headSetOutputRoutes = @[AVAudioSessionPortHeadphones,
                                     AVAudioSessionPortUSBAudio];
    for (AVAudioSessionPortDescription *description in outputs) {
        if ([headSetOutputRoutes containsObject:description.portType]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldShowEarphoneAlert {
    // 只要不是用手机内置的听筒或者喇叭作为声音外放的，都认为用户带了耳机
    NSArray *outputs = self.currentRoute.outputs;
    NSArray *headSetOutputRoutes = @[AVAudioSessionPortBuiltInReceiver,
                                     AVAudioSessionPortBuiltInSpeaker];
    for (AVAudioSessionPortDescription *description in outputs) {
        if ([headSetOutputRoutes containsObject:description.portType]) {
            return YES;
        }
    }
    return NO;
}

@end
