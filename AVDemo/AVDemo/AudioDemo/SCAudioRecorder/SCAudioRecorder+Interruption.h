//
//  SCAudioRecorder+Interruption.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/8.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCAudioRecorder.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCAudioRecorder (Interruption)

- (void)addAudioSessionInterruptedObserver;
- (void)removeAudioSessionInterruptedObserver;

@end

NS_ASSUME_NONNULL_END
