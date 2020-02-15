//
//  AUAudioRecorder+Interruption.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioRecorder.h"

NS_ASSUME_NONNULL_BEGIN

@interface AUAudioRecorder (Interruption)

- (void)addAudioSessionInterruptedObserver;
- (void)removeAudioSessionInterruptedObserver;

@end

NS_ASSUME_NONNULL_END
