//
//  SCAudioSession.m
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/12.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "SCAudioSession.h"
#import "AVAudioSession+RouteUtils.h"

const NSTimeInterval AUSAudioSessionLatency_Background = 0.0929;
const NSTimeInterval AUSAudioSessionLatency_Default = 0.0232;
const NSTimeInterval AUSAudioSessionLatency_LowLatency = 0.0058;

@implementation SCAudioSession

+ (instancetype)sharedInstance {
    static SCAudioSession *instance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [SCAudioSession new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _preferredSampleRate = _currentSampleRate = 44100.0;
        _audioSession = [AVAudioSession sharedInstance];
    }
    return self;
}

- (void)addRouteChangeListener {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(onNotificationAudioRouteChange:)
     name:AVAudioSessionRouteChangeNotification
     object:nil];
    [self adjustOnRouteChange];
}

#pragma mark - notification observer
- (void)onNotificationAudioRouteChange:(NSNotification *)sender {
    [self adjustOnRouteChange];
}

- (void)adjustOnRouteChange {
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    if (currentRoute) {
        if ([[AVAudioSession sharedInstance] usingWiredMicrophone]) {
            
        } else {
            if (![[AVAudioSession sharedInstance] usingBlueTooth]) {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            }
        }
    }
}

#pragma mark - setter
- (void)setCategory:(NSString *)category {
    _category = category;
    
    NSError *error = nil;
    if(![self.audioSession setCategory:_category
                           withOptions:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                                 error:&error])
        NSLog(@"Could note set category on audio session: %@", error.localizedDescription);
}

- (void)setActive:(BOOL)active {
    _active = active;
    
    NSError *error = nil;
    if(![self.audioSession setPreferredSampleRate:self.preferredSampleRate error:&error])
        NSLog(@"Error when setting sample rate on audio session: %@", error.localizedDescription);
    
    if(![self.audioSession setActive:_active error:&error])
        NSLog(@"Error when setting active state of audio session: %@", error.localizedDescription);
    
    _currentSampleRate = [self.audioSession sampleRate];
}

- (void)setPreferredLatency:(NSTimeInterval)preferredLatency {
    _preferredLatency = preferredLatency;
    
    NSError *error = nil;
    if(![self.audioSession setPreferredIOBufferDuration:_preferredLatency error:&error])
        NSLog(@"Error when setting preferred I/O buffer duration");
}

@end
