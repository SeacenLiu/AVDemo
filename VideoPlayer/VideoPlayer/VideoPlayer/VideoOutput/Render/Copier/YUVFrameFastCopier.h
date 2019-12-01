//
//  YUVFrameFastCopier.h
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "YUVFrameCopier.h"

@class VideoFrame;
@interface YUVFrameFastCopier : YUVFrameCopier

- (void)renderWithTexId:(VideoFrame*)videoFrame;

@end
