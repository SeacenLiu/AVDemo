//
//  SCAudioRecorder+Interruption.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/8.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCAudioRecorder+Interruption.h"

@implementation SCAudioRecorder (Interruption)

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
        case AVAudioSessionInterruptionTypeBegan:
            [self stopRecord];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self startRecord];
            break;
        default:
            break;
    }
}

@end
