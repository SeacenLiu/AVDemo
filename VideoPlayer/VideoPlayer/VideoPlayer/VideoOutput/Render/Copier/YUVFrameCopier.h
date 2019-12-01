//
//  YUVFrameCopier.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "BaseEffectFilter.h"

@class VideoFrame;
@interface YUVFrameCopier : BaseEffectFilter

- (void)renderWithTexId:(VideoFrame*)videoFrame;

@end
