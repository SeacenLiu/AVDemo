//
//  AVAudioSession+RouteUtils.m
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/13.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "AVAudioSession+RouteUtils.h"

/// AVAudioSessionPort 是音频会话接口，用于辨别输入输出的硬件接口
/** 输入接口
    AVAudioSessionPortLineIn: 有线连接在总线坞的外置输入装置
    AVAudioSessionPortBuiltInMic: 内置麦克风
    AVAudioSessionPortHeadsetMic: 有线耳机的麦克风
 */
/** 输出接口
    AVAudioSessionPortLineOut: 有线连接在总线坞的外置输出装置
    AVAudioSessionPortHeadphones: 有线耳机
    AVAudioSessionPortBluetoothA2DP: 蓝牙无线设备(A2DP)
    AVAudioSessionPortBuiltInReceiver: 听筒
    AVAudioSessionPortBuiltInSpeaker: 内置扬声器
    AVAudioSessionPortHDMI: 通过HDMI(高清多媒体接口)连接的设备
    AVAudioSessionPortAirPlay: 远程 AirPlay 设备
    AVAudioSessionPortBluetoothLE: 低能耗蓝牙设备
 */
/** 输入输出接口
    AVAudioSessionPortBluetoothHFP: 基于蓝牙的免提设备
    AVAudioSessionPortUSBAudio: USB连接的设备
    AVAudioSessionPortCarAudio: 车载音频设备
 */

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
