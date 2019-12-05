//
//  AVAudioSession+RouteUtils.h
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/13.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioSession (RouteUtils)

/** 是否使用蓝牙 */
- (BOOL)usingBlueTooth;

/** 是否使用有线麦克风 */
- (BOOL)usingWiredMicrophone;

/** 是否佩戴耳机 */
- (BOOL)shouldShowEarphoneAlert;

@end

NS_ASSUME_NONNULL_END
