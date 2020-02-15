//
//  AUAudioOutput+Interruption.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/31.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioOutput+Interruption.h"

@implementation AUAudioOutput (Interruption)

- (void)addAudioSessionInterruptedObserver {
    [self removeAudioSessionInterruptedObserver];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeAudioSessionInterruptedObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
}

- (void)onNotificationAudioInterrupted:(NSNotification *)sender {
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan: // 打断开始
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded: // 打断结束
            [self play];
            break;
        default:
            break;
    }
}

@end
