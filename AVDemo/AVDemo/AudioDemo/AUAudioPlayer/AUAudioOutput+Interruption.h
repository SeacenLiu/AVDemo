//
//  AUAudioOutput+Interruption.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/31.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface AUAudioOutput (Interruption)

- (void)addAudioSessionInterruptedObserver;
- (void)removeAudioSessionInterruptedObserver;

@end

NS_ASSUME_NONNULL_END
